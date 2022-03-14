use std::{
    io::stdout,
    sync::mpsc,
    thread,
    time::Duration,
};

use tui::{
    Terminal,
    Frame,
    backend::{Backend, CrosstermBackend},
    widgets::{Tabs, Block, Borders, Paragraph, Wrap, BorderType, ListItem, List},
    layout::{Layout, Constraint, Direction, Rect},
    text::{Span, Spans, Text},
    style::{Style, Color, Modifier},
    symbols::DOT,
};

use crossterm::{
    execute,
    event::{self, EnableMouseCapture, DisableMouseCapture, Event as CEvent, KeyEvent, KeyCode, KeyModifiers},
    terminal::{enable_raw_mode, disable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};

use snafu::{ResultExt, Snafu};

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("Failure in Crossterm Terminal Backend: {}", source))]
    CrosstermError { source: std::io::Error },

    #[snafu(display("Failed to receive Input event: {}", source))]
    ReceiveInput { source: std::sync::mpsc::RecvError },

    #[snafu(display("Failed to handle Input event: {}", source))]
    HandleInput { source: std::io::Error },

    //#[snafu(display("Failed to send Input event!"))]
    //SendInput { source: std::sync::mpsc::SendError<T = Event<I, H> },
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

use crate::app::App;


// Define Instructions (see key press in event loop for reference)
//const INSTRUCTIONS: &str = r#"'q' Quit  'r' Peek/Redraw UI"#;

// Define an Event which can consist of a pressed key or a Tick which occurs when the UI should be
// updated while no key got pressed
enum Event<I, H> {
    Input(I),
    Resize(H, H),
    //Tick, // Maybe update app for Ticks?
}


pub fn setup(app: &mut App) -> Result<()> {
    // Raw mode disables some common terminal functions that are unnecessary in the TUI environment
    enable_raw_mode().context(CrosstermError {})?;

    // Enter the Alternate Screen, so we don't break terminal history (it's like opening vim)
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture).context(CrosstermError {})?;

    // Initialize Crossterm backend
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend).context(CrosstermError {})?;

    // Clear the Alternate Screen if someone left it dirty
    terminal.clear().context(CrosstermError {})?;

    // Save the result of the main loop to return it after tearing down the backend
    let result = run_event_loop(app, &mut terminal);

    // Leave Alternate Screen to shut down cleanly regardless of the result
    disable_raw_mode().context(CrosstermError {})?;
    execute!(terminal.backend_mut(), DisableMouseCapture, LeaveAlternateScreen).context(CrosstermError {})?;
    terminal.show_cursor().context(CrosstermError {})?;

    // Return the result of the main loop after restoring the previous terminal state in order to
    // not be stuck in the Alternate Screen / or Raw Mode which would make a `reset` of the shell
    // necessary
    result
}

fn run_event_loop<B: Backend>(app: &mut App, mut terminal: &mut Terminal<B>) -> Result<()> {
    // Setup input handling as in the crossterm demo with a multi producer single consumer (mpsc) channel
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        loop {
            if event::poll(Duration::from_millis(250)).expect("Event loop: could not poll for events!") {
                if let CEvent::Key(key) = event::read().expect("Event loop: could not read a key event!") {
                    tx.send(Event::Input(key)).expect("Event loop: could not send an input event!");
                } else if let CEvent::Resize(w, h) = event::read().expect("Event loop: could not read a resize event!") {
                    tx.send(Event::Resize(w, h)).expect("Event loop: could not send a resize event!");
                }
            }
        }
    });

    // Event loop
    loop {
        // Update UI
        draw(app, &mut terminal)?;

        // Handle events
        match rx.recv().context(ReceiveInput {})? {
            // Match key pressed events
            Event::Input(event) => match event {
                // with Shift modifier
                KeyEvent {
                    modifiers: KeyModifiers::SHIFT,
                    code,
                } => match code {
                    // Press 'Shift+Tab' to switch backward between tabs
                    // TODO: This doesn't work! Why?
                    KeyCode::Tab => app.previous_tab(),
                    _ => {},
                },
                // without any modifiers
                KeyEvent {
                    modifiers: KeyModifiers::NONE,
                    code,
                } => match code {
                    // Press 'q' to quit application
                    KeyCode::Char('q') => return Ok(()),
                    // Press 'r' to redraw the UI
                    KeyCode::Char('r') => continue,
                    // Press 'Tab' to switch forward between tabs
                    KeyCode::Tab => app.next_tab(),
                    // Press ↑ or 'k' to go up in the list of PEs/Registers
                    KeyCode::Up | KeyCode::Char('k') => app.on_up(),
                    // Press ↓ or 'j' to go down in the list of PEs/Registers
                    KeyCode::Down | KeyCode::Char('j') => app.on_down(),
                    // Press Escape or 'h' to return back to the list of PEs
                    KeyCode::Esc | KeyCode::Char('h') => app.on_escape(),
                    // Press Enter or 'l' to select a PE/Register
                    KeyCode::Enter | KeyCode::Char('l') => app.on_return(),
                    _ => {},
                },
                _ => {},
            },
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
            .margin(1)
            .constraints(
                [
                    Constraint::Length(3),
                    Constraint::Min(0),
                ].as_ref()
            )
            .split(f.size());

        // Map the titles of the Tabs into Spans to be able to highlight the title of the
        // selected Tab
        let titles = app.tabs.titles
            .iter()
            .map(|t| Spans::from(Span::styled(*t, Style::default())))
            .collect();
        let tabs = Tabs::new(titles)
            .block(Block::default()
                .title(Span::styled(app.title,
                                    Style::default().add_modifier(Modifier::DIM)))
                .border_type(BorderType::Rounded)
                .border_style(Style::default().add_modifier(Modifier::DIM))
                .borders(Borders::ALL))
            .style(Style::default()
                .fg(Color::White))
            .highlight_style(
                Style::default()
                    .fg(Color::Blue)
                    .add_modifier(Modifier::BOLD)
                )
            .divider(DOT)
            .select(app.tabs.index);

        f.render_widget(tabs, tabs_chunks[0]);

        // Call the specific draw function for the selected Tab
        match app.tabs.index {
            0 => draw_first_tab(f, app, tabs_chunks[1]),
            1 => draw_second_tab(f, app, tabs_chunks[1]),
            _ => {},
        }
    }).context(CrosstermError {})?;

    Ok(())
}

fn draw_first_tab<B: Backend>(f: &mut Frame<B>, app: &mut App, chunk: Rect) {
    // Create a vertical layout (top to bottom) first to split the Tab into 3 rows
    let vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints(
            [
                Constraint::Percentage(65),
                Constraint::Percentage(30),
                Constraint::Length(3),
            ].as_ref()
        )
        .split(chunk);

    // Split the first row into half (okay golden ratio) vertically again
    let inner_vertical_chunks = Layout::default()
        //.direction(Direction::Horizontal)
        .direction(Direction::Vertical)
        .margin(0)
        .constraints(
            [
                Constraint::Percentage(35),
                Constraint::Percentage(65),
            ].as_ref()
        )
        .split(vertical_chunks[0]);

    // Split the first row's second row into half (okay golden ratio) horizontally
    let first_horizontal_chunks = Layout::default()
        .direction(Direction::Horizontal)
        //.direction(Direction::Vertical)
        .margin(0)
        .constraints(
            [
                Constraint::Percentage(65),
                Constraint::Percentage(35),
            ].as_ref()
        )
        .split(inner_vertical_chunks[1]);

    let triple_vertical_chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(0)
        .constraints(
            [
                Constraint::Percentage(33),
                Constraint::Percentage(33),
                Constraint::Percentage(33),
            ].as_ref()
        )
        .split(first_horizontal_chunks[1]);

    // Split the second row into half (okay golden ratio)
    let second_horizontal_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .margin(0)
        .constraints(
            [
                Constraint::Percentage(35),
                Constraint::Percentage(65),
            ].as_ref()
        )
        .split(vertical_chunks[1]);

    // Draw the PEs as stateful list to be able to select one
    let pes: Vec<ListItem> = app.pe_infos.items.iter()
        .map(|i| ListItem::new(vec![Spans::from(Span::raw(i))]))
        .collect();
    let pes = List::new(pes)
        .block(new_dim_block("PE List: ↓,j/↑,k/Enter,l to switch to PE Registers"))
        .highlight_style(Style::default().add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");
    f.render_stateful_widget(pes, inner_vertical_chunks[0], &mut app.pe_infos.state);

    draw_block_with_paragraph(f, "Register List: ↓,j/↑,k/Enter,l to set Register",
                              app.read_pe_registers(app.pe_infos.state.selected()),
                              first_horizontal_chunks[0]);

    // Also show info about Local Memory, Debug Cores and Interrupts
    draw_block_with_paragraph(f, "Local Memory",
                              "No info about Local Memory yet.",
                              triple_vertical_chunks[0]);
    draw_block_with_paragraph(f, "Debug Cores",
                              "No info about Debug Cores yet.",
                              triple_vertical_chunks[1]);
    draw_block_with_paragraph(f, "Interrupts",
                              "No info about Interrupts yet.",
                              triple_vertical_chunks[2]);

    draw_block_with_paragraph(f, "Bitstream & Device Info", app.get_bitstream_info(), second_horizontal_chunks[0]);
    draw_block_with_paragraph(f, "Platform Components", app.get_platform_info(), second_horizontal_chunks[1]);

    // Define Instructions (see key press in event loop for reference)
    let instructions = Spans::from(vec![
                                   Span::raw(" "),
                                   Span::styled("q", Style::default().add_modifier(Modifier::BOLD)),
                                   Span::from(" Quit"),
                                   Span::raw("    "),
                                   Span::styled("r", Style::default().add_modifier(Modifier::BOLD)),
                                   Span::from(" Peek/Redraw"),
                                   Span::raw("       "),
                                   Span::styled("Remember to quit before reprogramming the FPGA or reloading the kernel module!",
                                                Style::default().add_modifier(Modifier::ITALIC)),
    ]);
    draw_block_with_paragraph(f, "Instructions", instructions, vertical_chunks[2]);
}

fn draw_second_tab<B: Backend>(f: &mut Frame<B>, _app: &App, chunk: Rect) {
    draw_block_with_paragraph(f, "Nothing to see here", "This still needs to be implemented.. Sorry!", chunk);
}

/// Draw a block with some text in it into the rectangular space given by chunk
//fn draw_block_with_paragraph<B: Backend>(f: &mut Frame<B>, block_title: &str, paragraph_text: &str, chunk: Rect) {
fn draw_block_with_paragraph<'a, B: Backend, T>(f: &mut Frame<B>, block_title: &str, text: T, chunk: Rect) where Text<'a>: From<T> {
    let block = new_dim_block(block_title);
    let paragraph = Paragraph::new(text)
        .block(block)
        .wrap(Wrap { trim: false });
    f.render_widget(paragraph, chunk);
}

/// Create a new Block with round corners in dim colors and the given title
fn new_dim_block(title: &str) -> Block {
    Block::default()
        .title(Span::styled(title, Style::default().add_modifier(Modifier::DIM)))
        .border_type(BorderType::Rounded)
        .border_style(Style::default().add_modifier(Modifier::DIM))
        .borders(Borders::ALL)
}
