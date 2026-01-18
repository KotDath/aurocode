import 'package:file_picker/file_picker.dart';

/// Service for native file dialogs.
class FileDialogService {
  /// Opens a file picker dialog to select a single file.
  Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  /// Opens a folder picker dialog.
  Future<String?> pickDirectory() async {
    return FilePicker.platform.getDirectoryPath();
  }

  /// Opens a save file dialog.
  Future<String?> pickSaveLocation({String? fileName}) async {
    return FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.any,
    );
  }
}
