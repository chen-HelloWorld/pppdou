import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart';

import '../models/bead_models.dart';

class ColorEngine {
  List<BeadColor> colors = const [];

  Future<void> load() async {
    final raw = await rootBundle.loadString('color_card/MRAD_color.json');
    final data = jsonDecode(raw) as List<dynamic>;
    colors = data.map((e) => BeadColor.fromJson(e as Map<String, dynamic>)).toList();
  }

  BeadColor byId(String id) => colors.firstWhere((color) => color.id == id);

  BeadColor closest(Color input) {
    return match(input).color;
  }

  ({BeadColor color, double distance, double margin}) match(Color input) {
    final target = _rgbToLab(input);
    BeadColor winner = colors.first;
    var distance = double.infinity;
    var runnerUp = double.infinity;
    for (final candidate in colors) {
      final value = deltaE2000(target, _rgbToLab(candidate.rgb));
      if (value < distance) {
        runnerUp = distance;
        distance = value;
        winner = candidate;
      } else if (value < runnerUp) {
        runnerUp = value;
      }
    }
    return (color: winner, distance: distance, margin: runnerUp - distance);
  }

  double distance(Color first, Color second) =>
      deltaE2000(_rgbToLab(first), _rgbToLab(second));

  List<double> _rgbToLab(Color color) {
    double linear(int channel) {
      final value = channel / 255.0;
      return value > .04045
          ? math.pow((value + .055) / 1.055, 2.4).toDouble()
          : value / 12.92;
    }

    final r = linear(color.red);
    final g = linear(color.green);
    final b = linear(color.blue);
    final x = (r * .4124 + g * .3576 + b * .1805) / .95047;
    final y = (r * .2126 + g * .7152 + b * .0722);
    final z = (r * .0193 + g * .1192 + b * .9505) / 1.08883;
    double f(double value) => value > .008856
        ? math.pow(value, 1 / 3).toDouble()
        : 7.787 * value + 16 / 116;
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
  }

  // CIEDE2000 implementation used for perceptual MRAD matching.
  double deltaE2000(List<double> lab1, List<double> lab2) {
    final l1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
    final l2 = lab2[0], a2 = lab2[1], b2 = lab2[2];
    final c1 = math.sqrt(a1 * a1 + b1 * b1);
    final c2 = math.sqrt(a2 * a2 + b2 * b2);
    final cBar = (c1 + c2) / 2;
    final g = .5 * (1 - math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7))));
    final ap1 = (1 + g) * a1, ap2 = (1 + g) * a2;
    final cp1 = math.sqrt(ap1 * ap1 + b1 * b1);
    final cp2 = math.sqrt(ap2 * ap2 + b2 * b2);
    double hp(double a, double b) {
      var h = math.atan2(b, a) * 180 / math.pi;
      if (h < 0) h += 360;
      return h;
    }
    final hp1 = hp(ap1, b1), hp2 = hp(ap2, b2);
    final dl = l2 - l1, dc = cp2 - cp1;
    var dh = hp2 - hp1;
    if (cp1 * cp2 == 0) dh = 0;
    if (dh > 180) dh -= 360;
    if (dh < -180) dh += 360;
    final dH = 2 * math.sqrt(cp1 * cp2) * math.sin((dh / 2) * math.pi / 180);
    final lBar = (l1 + l2) / 2, cpBar = (cp1 + cp2) / 2;
    var hpBar = (hp1 + hp2) / 2;
    if (cp1 * cp2 != 0 && (hp1 - hp2).abs() > 180) hpBar += hp1 + hp2 < 360 ? 180 : -180;
    final t = 1 - .17 * math.cos((hpBar - 30) * math.pi / 180) +
        .24 * math.cos(2 * hpBar * math.pi / 180) +
        .32 * math.cos((3 * hpBar + 6) * math.pi / 180) -
        .20 * math.cos((4 * hpBar - 63) * math.pi / 180);
    final sl = 1 + .015 * math.pow(lBar - 50, 2) / math.sqrt(20 + math.pow(lBar - 50, 2));
    final sc = 1 + .045 * cpBar;
    final sh = 1 + .015 * cpBar * t;
    final rt = -2 * math.sqrt(math.pow(cpBar, 7) / (math.pow(cpBar, 7) + math.pow(25, 7))) *
        math.sin(60 * math.exp(-math.pow((hpBar - 275) / 25, 2)) * math.pi / 180);
    return math.sqrt(math.pow(dl / sl, 2) + math.pow(dc / sc, 2) +
        math.pow(dH / sh, 2) + rt * (dc / sc) * (dH / sh));
  }
}
