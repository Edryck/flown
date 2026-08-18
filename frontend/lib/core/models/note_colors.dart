import 'package:flutter/material.dart';

/// Paleta de cores "post-it" pras anotações - deliberadamente separada da
/// paleta de `Project` (`project_form_dialog.dart`, tons mais saturados,
/// "cor de marca"): aqui são tons pastel de papel, pra combinar com a ideia
/// de mural/quadro de recados, não com identidade visual de projeto.
const noteColorOptions = [
  (label: 'Amarelo', value: Color(0xFFFDE68A)),
  (label: 'Pêssego', value: Color(0xFFFED7AA)),
  (label: 'Rosa', value: Color(0xFFFBCFE8)),
  (label: 'Verde', value: Color(0xFFBBF7D0)),
  (label: 'Azul', value: Color(0xFFBFDBFE)),
  (label: 'Roxo', value: Color(0xFFDDD6FE)),
  (label: 'Cinza', value: Color(0xFFE5E7EB)),
];

const defaultNoteColorHex = '#FDE68A';

String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color colorFromHex(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
