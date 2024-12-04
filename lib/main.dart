import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  // 1. Flutter 앱이 실행될 준비가 됐는지 확인 : material.dart 에서 제공
  // main() 함수의 첫 실행값이 runApp() 이면 불필요
  // 다른 코드가 먼저 실행돼야 하면 꼭 제일 먼저 실행해줘야 함
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 핸드폰에 있는 카메라들 가져오기
  // 기기에서 사용할 수 있는 카메라들을 가져옴
  _cameras = await availableCameras();
  runApp(const CameraApp());
}

class CameraApp extends StatefulWidget {
  const CameraApp({Key? key}) : super(key: key);

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  // 3. 카메라를 제어할 수 있는 컨트롤러 선언
  late CameraController controller;

  @override
  void initState() {
    super.initState();

    initializeCamera();
  }

  initializeCamera() async {
    try {
      // 4. 가장 첫 번째 카메라로 카메라 설정하기
      controller = CameraController(_cameras[0], ResolutionPreset.max);

      // 5. 카메라 초기화
      await controller.initialize();

      setState(() {});
    } catch (e) {
      // 에러났을 때 출력
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    // 컨트롤러 삭제
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 6. 카메라 초기화 상태 확인
    if (!controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      // 7. 카메라 보여주기
      // CameraPreview 위젯 사용시 카메라를 화면에 보여줄 수 있음
      // 첫 번째 매개변수에 CameraController 입력 필요
      home: CameraPreview(controller),
    );
  }
}