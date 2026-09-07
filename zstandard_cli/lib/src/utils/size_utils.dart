import 'dart:io';

Future<String> getFileSize(File file) async {
  try {
    final int bytes = await file.length();
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;

    String size;
    if (bytes >= gb) {
      size = '${(bytes / gb).toStringAsFixed(2)} GB';
    } else if (bytes >= mb) {
      size = '${(bytes / mb).toStringAsFixed(2)} MB';
    } else if (bytes >= kb) {
      size = '${(bytes / kb).toStringAsFixed(2)} KB';
    } else {
      size = '$bytes bytes';
    }

    return size;
  } catch (e) {
    print('Error reading file size: $e');
    return '';
  }
}
