import 'package:flutter/material.dart';

/// Ícone oficial do WhatsApp desenhado em vetor.
///
/// Mantém o app sem dependências extras e garante o reconhecimento imediato do
/// botão de conversa.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({
    super.key,
    this.size = 22,
    this.color = const Color(0xFF25D366),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WhatsAppPainter(color), isComplex: false),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  _WhatsAppPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _parseSvgPath(_whatsappGlyph);
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Glifo oficial (Simple Icons, viewBox 24x24).
const String _whatsappGlyph =
    'M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15'
    '-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463'
    '-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606'
    '.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025'
    '-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008'
    '-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0'
    ' 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262'
    '.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413'
    '.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h'
    '-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a'
    '9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03'
    ' 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m'
    '8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096'
    '.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h'
    '.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z';

final RegExp _numberPattern = RegExp(r'[+-]?(?:\d+\.?\d*|\.\d+)');

Path _parseSvgPath(String source) {
  final parser = _SvgPathParser(source);
  return parser.parse();
}

class _SvgPathParser {
  _SvgPathParser(this.source);

  final String source;
  int _index = 0;

  void _skipSeparators() {
    while (_index < source.length) {
      final code = source.codeUnitAt(_index);
      if (code == 0x20 ||
          code == 0x2C ||
          code == 0x0A ||
          code == 0x0D ||
          code == 0x09) {
        _index++;
      } else {
        break;
      }
    }
  }

  bool get _hasMore {
    _skipSeparators();
    return _index < source.length;
  }

  bool get _isCommand {
    _skipSeparators();
    if (_index >= source.length) return false;
    final code = source.codeUnitAt(_index);
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  String _readCommand() {
    _skipSeparators();
    final command = source[_index];
    _index++;
    return command;
  }

  double _readNumber() {
    _skipSeparators();
    final match = _numberPattern.matchAsPrefix(source, _index);
    if (match == null) {
      throw FormatException('Número inválido na posição $_index.');
    }
    _index = match.end;
    return double.parse(match.group(0)!);
  }

  bool _readFlag() {
    _skipSeparators();
    final flag = source[_index] == '1';
    _index++;
    return flag;
  }

  Path parse() {
    final path = Path();
    double currentX = 0;
    double currentY = 0;
    double startX = 0;
    double startY = 0;
    String? previousCommand;

    while (_hasMore) {
      String command;
      if (_isCommand) {
        command = _readCommand();
      } else if (previousCommand != null) {
        command = previousCommand;
        if (command == 'M') command = 'L';
        if (command == 'm') command = 'l';
      } else {
        throw const FormatException('Comando SVG ausente.');
      }

      final relative = command == command.toLowerCase();
      switch (command.toUpperCase()) {
        case 'M':
          var x = _readNumber();
          var y = _readNumber();
          if (relative) {
            x += currentX;
            y += currentY;
          }
          path.moveTo(x, y);
          currentX = x;
          currentY = y;
          startX = x;
          startY = y;
        case 'L':
          var x = _readNumber();
          var y = _readNumber();
          if (relative) {
            x += currentX;
            y += currentY;
          }
          path.lineTo(x, y);
          currentX = x;
          currentY = y;
        case 'H':
          var x = _readNumber();
          if (relative) x += currentX;
          path.lineTo(x, currentY);
          currentX = x;
        case 'V':
          var y = _readNumber();
          if (relative) y += currentY;
          path.lineTo(currentX, y);
          currentY = y;
        case 'C':
          var x1 = _readNumber();
          var y1 = _readNumber();
          var x2 = _readNumber();
          var y2 = _readNumber();
          var x = _readNumber();
          var y = _readNumber();
          if (relative) {
            x1 += currentX;
            y1 += currentY;
            x2 += currentX;
            y2 += currentY;
            x += currentX;
            y += currentY;
          }
          path.cubicTo(x1, y1, x2, y2, x, y);
          currentX = x;
          currentY = y;
        case 'A':
          final rx = _readNumber();
          final ry = _readNumber();
          final rotation = _readNumber();
          final largeArc = _readFlag();
          final sweep = _readFlag();
          var x = _readNumber();
          var y = _readNumber();
          if (relative) {
            x += currentX;
            y += currentY;
          }
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation * 3.1415926535897932 / 180,
            largeArc: largeArc,
            clockwise: sweep,
          );
          currentX = x;
          currentY = y;
        case 'Z':
          path.close();
          currentX = startX;
          currentY = startY;
        default:
          throw FormatException('Comando SVG não suportado: $command');
      }
      previousCommand = command;
    }
    return path;
  }
}
