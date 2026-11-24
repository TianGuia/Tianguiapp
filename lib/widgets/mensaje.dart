import 'package:flutter/material.dart';

// el aviso de abajo que sale en varias pantallas
void mostrarMensaje(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
