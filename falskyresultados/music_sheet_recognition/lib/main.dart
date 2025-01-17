import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  List<dynamic>? _recognizedNotes;
  int _imageWidth = 0;
  int _imageHeight = 0;

  Future<void> getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final image = File(pickedFile.path);
      final decodedImage = img.decodeImage(await image.readAsBytes());

      setState(() {
        _image = image;
        _imageWidth = decodedImage?.width ?? 0;
        _imageHeight = decodedImage?.height ?? 0;
        _recognizedNotes = null; // Reset the recognized notes
      });
    }
  }

  Future<void> detectNotes() async {
    if (_image == null) return;

    final request = http.MultipartRequest('POST', Uri.parse('http://192.168.0.13:5000/detect'));
    request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final json = jsonDecode(responseData);

      setState(() {
        _recognizedNotes = json['notes'];
      });

      // Print the classes of detected notes for debugging
      _recognizedNotes?.forEach((note) {
        print('Detected note class: ${note['class']}');
      });

    } else {
      print('Failed to detect notes');
    }
  }

  Future<void> convertToXml() async {
    if (_recognizedNotes == null) return;

    final response = await http.post(
      Uri.parse('http://192.168.175.62:5000/convert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'notes': _recognizedNotes}),
    );

    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/output_${DateTime.now().millisecondsSinceEpoch}.xml';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      print('XML saved to $filePath');
    } else {
      print('Failed to convert to XML');
    }
  }

  void _launchURL(String noteClass) async {
    final urls = {
      'Clave de sol': 'https://es.wikipedia.org/wiki/Clave_de_sol',
      'Clave de fa': 'https://es.wikipedia.org/wiki/Clave_de_fa',
      'negra': 'https://es.wikipedia.org/wiki/Negra_(m%C3%BAsica)',
      'corchea': 'https://es.wikipedia.org/wiki/Corchea',
      'semicorchea': 'https://es.wikipedia.org/wiki/Semicorchea',
      // Agrega más enlaces según sea necesario
    };

    final url = urls[noteClass];
    if (url != null && await canLaunch(url)) {
      await launch(url);
    } else {
      print('No se puede abrir el enlace: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ASMusicScribe'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '¡Bienvenido a ASMusicScribe!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Transforma tus partituras en magia digital',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.teal[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => getImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shadowColor: Colors.tealAccent,
                    elevation: 10,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: TextStyle(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                  child: Text('Tomar Foto', style: TextStyle(color: Colors.white)),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => getImage(ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shadowColor: Colors.tealAccent,
                    elevation: 10,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: TextStyle(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                  child: Text('Elegir de Galería', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: 20),
            _image != null
                ? Expanded(
                    child: Stack(
                      children: [
                        Image.file(_image!),
                        if (_recognizedNotes != null)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double scaleX = constraints.maxWidth / _imageWidth;
                              final double scaleY = constraints.maxHeight / _imageHeight;
                              return Stack(
                                children: _recognizedNotes!.map((note) {
                                  final x1 = note['x1'] * scaleX;
                                  final y1 = note['y1'] * scaleY;
                                  final x2 = note['x2'] * scaleX;
                                  final y2 = note['y2'] * scaleY;
                                  return Positioned(
                                    left: x1,
                                    top: y1,
                                    width: x2 - x1,
                                    height: y2 - y1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.red, width: 2),
                                      ),
                                      child: Center(
                                        child: Text(
                                          note['class'],
                                          style: TextStyle(color: Colors.white, backgroundColor: Colors.black),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  )
                : Container(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: detectNotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shadowColor: Colors.tealAccent,
                elevation: 10,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                textStyle: TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
              child: Text('Detectar Notas', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: convertToXml,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shadowColor: Colors.tealAccent,
                elevation: 10,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                textStyle: TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
              child: Text('Convertir a XML', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 20),
            _recognizedNotes != null
                ? Expanded(
                    child: ListView.builder(
                      itemCount: _recognizedNotes!.length,
                      itemBuilder: (context, index) {
                        final note = _recognizedNotes![index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            title: Text(
                              'Clase: ${note['class']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            subtitle: Text(
                              'Coordenadas: (${note['x1']}, ${note['y1']}) - (${note['x2']}, ${note['y2']})',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.info_outline, color: Colors.teal),
                              onPressed: () => _launchURL(note['class']),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
