use std::{io::stdout, sync::mpsc, thread, time::Duration};

use log::trace;

use tui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    symbols::DOT,
    text::{Span, Spans, Text},
    widgets::{Block, BorderType, Borders, List, ListItem, Paragraph, Tabs, Wrap},
    Frame, Terminal,
};

use crossterm::{
    event::{self, Event as CEvent, KeyCode, KeyEvent, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};

use unicode_width::UnicodeWidthStr;

use snafu::{ResultExt, Snafu};

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Failure in Crossterm Terminal Backend: {}", source))]
    Crossterm { source: std::io::Error },

    #[snafu(display("Failed to receive Input event: {}", source))]
    ReceiveInput { source: std::sync::mpsc::RecvError },

    #[snafu(display("Failed to handle Input event: {}", source))]
    HandleInput { source: std::io::Error },
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

use crate::app::{AccessMode, App, InputFrame, InputMode};

// Define an Event which can consist of a pressed key or the terminal got resized.
enum Event<I, H> {
    Input(I),
    Resize(H, H),
    // TODO: Maybe add a tick event which occurs when the UI should be updated while no key got pressed?
}

pub fn setup(app: &mut App) -> Result<()> {
    // Raw mode disables some common terminal functions that are unnecessary in the TUI environment
    enable_raw_mode().context(Crossterm {})?;

    // Enter the Alternate Screen, so we don't break terminal history (it's like opening vim)
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen).context(Crossterm {})?;

    // Initialize Crossterm backend
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context(Crossterm {})?;

    // Clear the Alternate Screen if someone left it dirty
    terminal.clear().context(Crossterm {})?;

    // Save the result of the main loop to return it after tearing down the backend
    let result = run_event_loop(app, &mut terminal);

    // Leave Alternate Screen to shut down cleanly regardless of the result
    disable_raw_mode().context(Crossterm {})?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen).context(Crossterm {})?;
    terminal.show_cursor().context(Crossterm {})?;

    // Return the result of the main loop after restoring the previous terminal state in order to
    // not be stuck in the Alternate Screen / or Raw Mode which would make a `reset` of the shell
    // necessary
    result
}

fn run_event_loop<B: Backend>(app: &mut App, terminal: &mut Terminal<B>) -> Result<()> {
    // Setup input handling as in the crossterm demo with a multi producer single consumer (mpsc) channel
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || loop {
        if event::poll(Duration::from_millis(250)).expect("Event loop: could not poll for events!")
        {
            if let CEvent::Key(key) =
                event::read().expect("Event loop: could not read a key event!")
            {
                tx.send(Event::Input(key))
                    .expect("Event loop: could not send an input event!");
            } else if let CEvent::Resize(w, h) =
                event::read().expect("Event loop: could not read a resize event!")
            {
                tx.send(Event::Resize(w, h))
                    .expect("Event loop: could not send a resize event!");
            }
        }
    });

    // Event loop
    loop {
        // Update UI
        draw(app, terminal)?;

        // Handle events
        match rx.recv().context(ReceiveInput {})? {
            // Match key pressed events
            Event::Input(event) => {
                trace!("Input event: {:?}", event);

                // Match the input mode, either you're in line input mode where you enter new
                // values for registers or you're in the default navigation mode.
                match app.input_mode {
                    InputMode::Edit => match event.code {
                        KeyCode::Char(c) => app.input.push(c),
                        KeyCode::Backspace => {
                            if app.input.pop().is_none() {
                                app.input_mode = InputMode::Navigation;
                            }
                        }
                        KeyCode::Enter => app.on_enter(),
                        KeyCode::Esc => app.on_escape(),
                        _ => {}
                    },
                    InputMode::Navigation => match event {
                        // Press 'Shift+Tab' to switch backward through tabs
                        KeyEvent {
                            modifiers: KeyModifiers::SHIFT,
                            code: KeyCode::BackTab,
                        } => app.previous_tab(),
                        // without any modifiers
                        KeyEvent {
                            modifiers: KeyModifiers::NONE,
                            code,
                        } => match code {
                            // Press 'q' to quit application
                            KeyCode::Char('q') => return Ok(()),
                            // Press 'r' to redraw the UI
                            KeyCode::Char('r') => continue,
                            // Press 'Tab' to switch forward through tabs
                            KeyCode::Tab => app.next_tab(),
                            // Press ↑ or 'k' to go up in the list of PEs/Registers
                            KeyCode::Up | KeyCode::Char('k') => app.on_up(),
                            // Press ↓ or 'j' to go down in the list of PEs/Registers
                            KeyCode::Down | KeyCode::Char('j') => app.on_down(),
                            // Press Escape or 'h' to return back to the list of PEs
                            KeyCode::Esc | KeyCode::Left | KeyCode::Char('h') => app.on_escape(),
                            // Press Enter or 'l' to select a PE/Register
                            KeyCode::Enter | KeyCode::Right | KeyCode::Char('l') => app.on_enter(),
                            // Press 's' on a selected PE to start a job
                            KeyCode::Char('s') => match app.access_mode {
                                AccessMode::Unsafe {} => app.messages.push(app.start_current_pe()),
                                AccessMode::Monitor {} => app.messages.push("Unsafe access mode necessary to start a PE. Restart the app with `unsafe` parameter.".to_string())
                            },
                            _ => {}
                        },
                        _ => {}
                    },
                }
            }
            // TODO: When opening a new pane in Tmux this app is not redrawn.
            Event::Resize(_, _) => continue,
        }
    }
}

fn draw<B: Backend>(app: &mut App, terminal: &mut Terminal<B>) -> Result<()> {
    terminal.draw(|f| {
        // Create a layout with fixed space for the Tab bar and a flexible space where each tab can
        // draw itself
        let tabs_chunks = Layout::default()
            .direction(Direction::Vertical)
            .margin(0)
            .constraints(
                [
                    Constraint::Length(2),
                    Constraint::Length(3),
                    Constraint::Min(0),
                ].as_ref()
            )
            .split(f.size());

        // Render title and general user instructions
        f.render_widget(
            Paragraph::new(
                Spans::from(vec![
                            Span::raw(&app.title),
                            Span::raw(" (q: Quit. "),
                            Span::styled("Remember to quit before reprogramming the FPGA or reloading the kernel module!",
                                         Style::default().add_modifier(Modifier::ITALIC)),
                                         Span::raw(")"),
                ])), tabs_chunks[0]);

        // Map the titles of the Tabs into Spans to be able to highlight the title of the
        // selected Tab
        let titles = app.tabs.titles
            .iter()
            .map(|t| Spans::from(Span::styled(*t, Style::default())))
            .collect();
        let tabs = Tabs::new(titles)
            .block(Block::default()
                .title(Span::styled("Tabs (Shift+Tab: \u{2190}, Tab: \u{2192})",
                                    Style::default().add_modifier(Modifier::DIM)))
                .border_type(BorderType::Rounded)
                .border_style(Style::default().add_modifier(Modifier::DIM))
                .borders(Borders::ALL))
            .style(Style::default()
                .fg(Color::White))
            .highlight_style(Style::default().add_modifier(Modifier::BOLD))
            .divider(DOT)
            .select(app.tabs.index);

        f.render_widget(tabs, tabs_chunks[1]);

        // Call the specific draw function for the selected Tab
        match app.tabs.index {
            0 => draw_tab_peek_and_poke_pes(f, app, tabs_chunks[2]),
            1 => draw_tab_platform_components(f, app, tabs_chunks[2]),
            2 => draw_tab_bitstream_and_device_info(f, app, tabs_chunks[2]),
            _ => {},
        }
    }).context(Crossterm {})?;

    Ok(())
}

fn draw_tab_peek_and_poke_pes<B: Backend>(f: &mut Frame<B>, app: &mut App, chunk: Rect) {
    // Create a vertical layout (top to bottom) first to split the Tab into 3 rows with a
    // bottom line for keyboard input that is only shown when in Edit Mode (that then replaces
    // the messages view):
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(0)
        .constraints(match app.input_mode {
            InputMode::Edit => [
                Constraint::Length(15),
                Constraint::Min(30),
                Constraint::Length(3),
            ]
            .as_ref(),
            InputMode::Navigation => [Constraint::Length(15), Constraint::Min(30), Constraint::Length(15)].as_ref(),
        })
        .split(chunk);

    // Split the second row into half horizontally
    let horizontal_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .margin(0)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)].as_ref())
        .split(vertical_chunks[1]);

    // Draw the PEs as stateful list to be able to select one
    let pes_title = if (app.access_mode == AccessMode::Monitor {}) {
        "PE List (j:\u{2193}, k:\u{2191})"
    } else {
        "PE List (j:\u{2193}, k:\u{2191}, s: start the selected PE, Enter/l: switch to Register List)"
    };
    let pes: Vec<ListItem> = app
        .pe_infos
        .items
        .iter()
        .map(|i| ListItem::new(vec![Spans::from(Span::raw(i))]))
        .collect();
    let pes = List::new(pes)
        .block(focusable_block(
            pes_title,
            app.focus == InputFrame::PEList {},
        ))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");
    f.render_stateful_widget(pes, vertical_chunks[0], &mut app.pe_infos.state);

    // Split the PE's registers into status plus return value and arguments
    let register_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(0)
        .constraints([Constraint::Length(5), Constraint::Min(10)].as_ref())
        .split(horizontal_chunks[0]);

    // Status registers
    draw_block_with_paragraph(
        f,
        "Status Registers",
        app.get_status_registers(),
        register_chunks[0],
    );

    // Argument Register List (also stateful list for editing)
    let registers_title = if (app.access_mode == AccessMode::Monitor {}) {
        "Register List (r: Refresh)"
    //} else if (app.access_mode == AccessMode::Debug {}) {
    //    "Register List (r: Refresh, Escape: back, j:\u{2193}, k:\u{2191}, Enter/l: set Register, s: Start PE)"
    } else {
        "Register List (r: Refresh, Escape: back, j:\u{2193}, k:\u{2191}, Enter/l: set Register)"
    };
    let registers = app.get_argument_registers(register_chunks[1].height.saturating_sub(2).into());
    let registers: Vec<ListItem> = registers
        .iter()
        .map(|i| ListItem::new(vec![Spans::from(Span::raw(i))]))
        .collect();
    let registers = List::new(registers)
        .block(focusable_block(
            registers_title,
            app.focus == InputFrame::RegisterList,
        ))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");
    f.render_stateful_widget(registers, register_chunks[1], &mut app.register_list);

    // Local Memory (also a stateful list for editing TODO?)
    // TODO: query and draw only as many addresses as there is space in the frame
    let local_memory = app.dump_current_pe_local_memory(horizontal_chunks[1].height.saturating_sub(2).into());
    let local_memory: Vec<ListItem> = local_memory
        .iter()
        .map(|i| ListItem::new(vec![Spans::from(Span::raw(i))]))
        .collect();
    let local_memory = List::new(local_memory)
        .block(focusable_block("Local Memory (r: Refresh)", false))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");
    f.render_stateful_widget(
        local_memory,
        horizontal_chunks[1],
        &mut app.local_memory_list,
    );

    // Draw an input line if in Edit Mode or the messages view when not in Edit Mode
    if app.input_mode == InputMode::Edit {
        let input = Paragraph::new(app.input.as_ref()).block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .title("Input (Escape: abort, Enter: try to parse input as signed decimal i64)")
                .style(Style::default().fg(Color::Yellow)),
        );
        let input_chunks = vertical_chunks[2];
        f.render_widget(input, input_chunks);

        // Make the cursor visible and ask tui-rs to put it at the specified coordinates after rendering
        f.set_cursor(
            // Put cursor past the end of the input text
            input_chunks.x + (app.input.width() + 1).try_into().unwrap_or(0),
            // Move one line down, from the border to the input line
            input_chunks.y + 1,
        );
    } else {
        draw_block_with_paragraph(
            f,
            "Messages",
            app.messages.iter().rev().take(vertical_chunks[2].height.saturating_sub(2).into()).rev().cloned().collect::<Vec<String>>().join("\n"),
            vertical_chunks[2],
        );
    }
}

fn draw_tab_platform_components<B: Backend>(f: &mut Frame<B>, app: &App, chunk: Rect) {
    // Create a vertical layout (top to bottom) first to split the Tab into 2 rows
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(0)
        .constraints([Constraint::Min(15), Constraint::Length(10)].as_ref())
        .split(chunk);

    // Show general info about platform components
    draw_block_with_paragraph(f, "Overview", app.get_platform_info(), vertical_chunks[0]);

    // and DMAEngine Statistics
    draw_block_with_paragraph(
        f,
        "DMAEngine Statistics (r: Refresh)",
        app.get_dmaengine_statistics(),
        vertical_chunks[1],
    );
}

fn draw_tab_bitstream_and_device_info<B: Backend>(f: &mut Frame<B>, app: &App, chunk: Rect) {
    draw_block_with_paragraph(f, "", app.get_bitstream_info(), chunk);
}

/// Draw a block with some text in it into the rectangular space given by chunk
fn draw_block_with_paragraph<'a, B: Backend, T>(
    f: &mut Frame<B>,
    block_title: &str,
    text: T,
    chunk: Rect,
) where
    Text<'a>: From<T>,
{
    let block = dim_block(block_title);
    let paragraph = Paragraph::new(text).block(block).wrap(Wrap { trim: false });
    f.render_widget(paragraph, chunk);
}

/// Create a new Block with round corners and the given title and choose the border style
fn block_with_border_style(title: &str, style: Modifier) -> Block {
    Block::default()
        .title(Span::styled(title, Style::default().add_modifier(style)))
        .border_type(BorderType::Rounded)
        .border_style(Style::default().add_modifier(style))
        .borders(Borders::ALL)
}

/// Create a new Block with round corners in dim colors and the given title
fn dim_block(title: &str) -> Block {
    block_with_border_style(title, Modifier::DIM)
}

/// Create a new Block with round corners which takes a boolean if it is focused
fn focusable_block(title: &str, focused: bool) -> Block {
    block_with_border_style(
        title,
        if focused {
            Modifier::BOLD
        } else {
            Modifier::DIM
        },
    )
}
