import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroExercicioPage extends StatefulWidget {
  const CadastroExercicioPage({Key? key}) : super(key: key);

  @override
  State<CadastroExercicioPage> createState() => _CadastroExercicioPageState();
}

class _CadastroExercicioPageState extends State<CadastroExercicioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _grupoController = TextEditingController();
  final _videoUrlController = TextEditingController();
  
  bool _estaCarregando = false;

  // Função principal para salvar o exercício no Firestore
  Future<void> _salvarExercicio() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _estaCarregando = true;
    });

    try {
      // Cria uma referência com ID único na coleção 'exercicios'
      final docRef = FirebaseFirestore.instance.collection('exercicios').doc();

      // Salva os dados textuais incluindo a URL informada pelo professor
      await docRef.set({
        'id': docRef.id,
        'nome': _nomeController.text.trim(),
        'grupoMuscular': _grupoController.text.trim(),
        'videoUrl': _videoUrlController.text.trim(), // Guarda o link do YouTube
        'criadoEm': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercício cadastrado com sucesso!')),
      );

      // Limpa os campos após salvar
      _nomeController.clear();
      _grupoController.clear();
      _videoUrlController.clear();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar exercício: $e')),
      );
    } finally {
      setState(() {
        _estaCarregando = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _grupoController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Exercício'),
        centerTitle: true,
      ),
      body: _estaCarregando 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Salvando no banco...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Campo Nome do Exercício
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Exercício',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fitness_center),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Insira o nome do exercício' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campo Grupo Muscular
                  TextFormField(
                    controller: _grupoController,
                    decoration: const InputDecoration(
                      labelText: 'Grupo Muscular (ex: Peito, Pernas)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.accessibility_new),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Insira o grupo muscular' : null,
                  ),
                  const SizedBox(height: 16),

                  // Campo Link do YouTube
                  TextFormField(
                    controller: _videoUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Link do Vídeo Demonstrativo (YouTube)',
                      hintText: 'https://www.youtube.com/watch?v=...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.video_library, color: Colors.red),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
                          return 'Por favor, insira um link válido do YouTube';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botão Salvar
                  ElevatedButton(
                    onPressed: _salvarExercicio,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: const Text(
                      'Salvar Exercício',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}