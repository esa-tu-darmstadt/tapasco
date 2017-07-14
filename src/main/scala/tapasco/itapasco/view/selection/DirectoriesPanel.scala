package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Button, BorderPanel, BoxPanel, TextField, FileChooser, Orientation, Label, Swing}
import  scala.swing.BorderPanel.Position._
import  scala.swing.event._
import  java.nio.file.{Path, Paths}
import  FileAssetManager.Events._

/**
 * DirectoriesPanel shows a number of edit fields for the base paths.
 * A button next to each can brings up a file select dialog.
 * @param m Model to associate with.
 */
protected[itapasco] class DirectoriesPanel extends BoxPanel(Orientation.Vertical) {
  import DirectoriesPanel._, DirectoriesPanel.Events._

  object Selection extends Publisher {
    type Event = DirectoriesPanel.Event
  }

  Entities() foreach { e =>
    contents += new BorderPanel { layout(new Label("%s directory:".format(e))) = West }
    contents += Swing.VStrut(2)
    contents += new EntityPathEditor(e, e => Selection.publish(EntityPathSelected(e)))
    contents += Swing.VStrut(1)
  }

  // set a 5px empty border
  border = Swing.EmptyBorder(BORDER_SZ)
}

/**
 * Directories panel companion object: Contains editor class.
 **/
protected[itapasco] object DirectoriesPanel {
  private final val BORDER_SZ = 5

  sealed trait Event
  final object Events {
    final case class EntityPathSelected(entity: Entity) extends Event
  }

  /**
   * Editor component for an entity base path.
   * Provides a text field and a directory selection button, which opens a
   * FileChooser dialog to select a directory. Text field can be used to
   * edit the path directly. Direct edits are used only on exit of focus
   * from the text field, not intermediately to reduce number of events.
   * Will set values in
   * [[de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager]]
   * and react on events from there.
   * @param entity Entities to select the path for.
   * @param select Callback function when this edit field was focussed.
   **/
  sealed class EntityPathEditor(entity: Entity, select: Entity => Unit)
      extends BorderPanel with Listener[FileAssetManager.Event] {
    private[this] val _edit  = new TextField() { text = FileAssetManager.basepath(entity).toString }
    private[this] val _dirBt = new Button("...")
    private[this] val _fc    = new FileChooser(FileAssetManager.TAPASCO_HOME.toFile) {
      fileSelectionMode = FileChooser.SelectionMode.DirectoriesOnly
    }
    // layout edit field and button in Center and East respectively
    layout(_edit) = Center
    layout(_dirBt) = East
    // listen to entity manager events regarding base paths
    FileAssetManager += this
    // listen to events from button and edit field
    listenTo(_dirBt, _edit)
    reactions += {
      // show directory chooser dialog on button click
      case ButtonClicked(`_dirBt`) => selectDirectory()
      // call select callback when edit field is focussed
      case FocusGained(`_edit`, _, temporary) => if (! temporary) select(entity)
      // set current value of edit field as new path for entities
      case FocusLost(`_edit`, _, temporary) => if (! temporary) FileAssetManager.basepath(entity).set(path)
    }

    def update(e: FileAssetManager.Event): Unit = e match {
      // update field values on change of base paths
      case BasePathChanged(`entity`, p) => _edit.text = p.toString
      case _ => {}
    }

    /** Returns the currently selected path. */
    def path: Path = Paths.get(_edit.text).toAbsolutePath().normalize()

    /** Shows the directory chooser and sets new path in FileAssetManager. */
    private def selectDirectory(): Unit = {
      if (_fc.showOpenDialog(this) == FileChooser.Result.Approve) {
        FileAssetManager.basepath(entity).set(Paths.get(_fc.selectedFile.toString).toAbsolutePath().normalize())
      }
    }
  }
}
