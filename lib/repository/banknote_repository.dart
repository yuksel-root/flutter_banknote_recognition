import 'package:camera/camera.dart';

import '../models/banknote_result.dart';

class BanknoteRepository {
  Future<BanknoteResult?> recognize(XFile image) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    return const BanknoteResult(
      value: '100 TL',
      confidence: 0.92,
      securityFeatures: [
        'Banknotun ön yüzünde, filigranın sol üst köşesindeki Braille noktalarına dokunun; iki kabartma nokta hissediyor olmalısınız.',
        'Banknotu ışığa tutun; Atatürk portresinin küçük görüntüsü ile 100 sayısından oluşan filigran belirir.',
        'Işığa tuttuğunuzda, üzerinde 100 ve TL yazan emniyet şeridi iki yüzden de kesintisiz görünür.',
      ],
    );
  }
}
