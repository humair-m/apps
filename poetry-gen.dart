import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoetryApp());
}

class PoetryApp extends StatelessWidget {
  const PoetryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poetry Creator',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.notoNastaliqUrduTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const PoetryForm(),
    );
  }
}

class PoetryForm extends StatefulWidget {
  const PoetryForm({Key? key}) : super(key: key);

  @override
  State<PoetryForm> createState() => _PoetryFormState();
}

class _PoetryFormState extends State<PoetryForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _poetryController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isProcessing = false;
  String _cssContent = '';

  @override
  void initState() {
    super.initState();
    _loadCssFile();
  }

  Future<void> _loadCssFile() async {
    try {
      // Load CSS content from assets
      _cssContent = await rootBundle.loadString('assets/style.css');
    } catch (e) {
      // If CSS file not found in assets, use default CSS
      _cssContent = '''
body {
  font-family: 'Noto Nastaliq Urdu', 'Amiri', serif;
  background-color: #f8f3e9;
  direction: rtl;
  margin: 0;
  padding: 0;
}
.container {
  max-width: 800px;
  margin: 20px auto;
  background-color: #fff;
  padding: 40px;
  box-shadow: 0 0 15px rgba(0, 0, 0, 0.1);
  position: relative;
  border: 1px solid #d4c9b0;
}
.decorative-pattern {
  height: 30px;
  background-image: repeating-linear-gradient(45deg, #d4c9b0 0px, #d4c9b0 1px, transparent 1px, transparent 10px);
  margin-bottom: 30px;
}
.title {
  text-align: center;
  color: #5d4037;
  font-size: 36px;
  margin-bottom: 30px;
}
.poetry {
  line-height: 2.5;
  font-size: 24px;
  text-align: center;
  margin-bottom: 40px;
}
.poetry p {
  margin: 15px 0;
}
.poet-name-container {
  text-align: left;
  margin-top: 30px;
}
.poet-name {
  display: inline-block;
  font-size: 22px;
  border-top: 1px solid #d4c9b0;
  padding-top: 10px;
  color: #5d4037;
}
.date {
  text-align: center;
  font-size: 18px;
  color: #7d6e63;
  margin-top: 20px;
}
''';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _poetryController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1800),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _generateAndDownloadHTML() async {
    // Prevent multiple taps
    if (_isProcessing) return;
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isProcessing = true;
      });
      
      try {
        // Request storage permissions for Android
        if (await _requestPermissions() == false) {
          setState(() {
            _isProcessing = false;
          });
          return;
        }

        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          );
        }

        // Get directory for saving file
        final directory = await _getStorageDirectory();
        if (directory == null) {
          _showErrorMessage('Could not access storage directory');
          return;
        }
        
        // Create file name with timestamp to avoid overwrites
        String timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        String htmlFileName = 'poetry_$timeStamp.html';
        String cssFileName = 'style_$timeStamp.css';
        
        final File htmlFile = File('${directory.path}/$htmlFileName');
        final File cssFile = File('${directory.path}/$cssFileName');
        
        // Write CSS content to file
        await cssFile.writeAsString(_cssContent);
        
        // Create HTML content referencing external CSS
        final String htmlContent = '''
<!DOCTYPE html>
<html lang="ur">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${_titleController.text}</title>
<link href="https://fonts.googleapis.com/css2?family=Amiri:ital,wght@0,400;0,700;1,400;1,700&family=Noto+Nastaliq+Urdu:wght@400;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="./${cssFileName}">
</head>
<body>
<div class="container">
<div class="decorative-pattern"></div>
<h1 class="title">${_titleController.text}</h1>
<div class="poetry">
${_formatPoetry(_poetryController.text)}
</div>
<div class="date">${DateFormat('dd MMMM yyyy').format(_selectedDate)}</div>
<div class="poet-name-container">
<div class="poet-name">${_nameController.text}</div>
</div>
</div>
</body>
</html>
''';

        // Write HTML content to file
        await htmlFile.writeAsString(htmlContent);
        
        // Hide loading indicator if context is still valid
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        // Share the HTML file
        await Share.shareXFiles(
          [XFile(htmlFile.path), XFile(cssFile.path)], 
          text: 'Poetry HTML file and CSS created'
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Files saved at: ${directory.path}')),
          );
        }
      } catch (e) {
        // Hide loading indicator if context is still valid
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        if (mounted) {
          _showErrorMessage('Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  Future<bool> _requestPermissions() async {
    // For Android permissions
    try {
      // Request basic storage permission first
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        var result = await Permission.storage.request();
        if (!result.isGranted) {
          _showErrorMessage('Storage permission is required');
          return false;
        }
      }
      
      // For Android 11+ (API 30+), try to request manage external storage
      if (Platform.isAndroid) {
        try {
          var externalStatus = await Permission.manageExternalStorage.status;
          if (!externalStatus.isGranted) {
            var result = await Permission.manageExternalStorage.request();
            if (!result.isGranted) {
              // This permission might not be critical on all devices/versions
              print('External storage management permission denied');
              // Continue with basic storage permission
            }
          }
        } catch (e) {
          // This permission might not be available on all Android versions
          print('manageExternalStorage permission not available: $e');
        }
      }
      
      return true;
    } catch (e) {
      _showErrorMessage('Error requesting permissions: $e');
      return false;
    }
  }

  Future<Directory?> _getStorageDirectory() async {
    try {
      // Try external storage first
      Directory? directory = await getExternalStorageDirectory();
      
      // Fall back to app documents directory if external isn't available
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }
      
      return directory;
    } catch (e) {
      _showErrorMessage('Error accessing storage: $e');
      return null;
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _formatPoetry(String poetry) {
    // Split by new line and wrap each line in <p> tags
    return poetry
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => '<p>$line</p>')
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poetry Creator'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _poetryController,
                  decoration: const InputDecoration(
                    labelText: 'Poetry Text',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 10,
                  minLines: 5, // Ensure enough initial height for Nastaliq script
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter poetry text';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Poet Name',
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter poet name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _generateAndDownloadHTML,
                  icon: _isProcessing 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        ) 
                      : const Icon(Icons.download),
                  label: Text(
                    _isProcessing ? 'Generating...' : 'Generate and Download HTML & CSS',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isProcessing 
                      ? null 
                      : () {
                          // Show preview
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(_titleController.text.isEmpty ? 'Preview' : _titleController.text),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _poetryController.text,
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: GoogleFonts.notoNastaliqUrdu(
                                        fontSize: 18,
                                        height: 2.0, // Line height for Nastaliq script
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _nameController.text,
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: GoogleFonts.notoNastaliqUrdu(
                                        fontSize: 16,
                                        color: Colors.brown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                  icon: const Icon(Icons.preview),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
