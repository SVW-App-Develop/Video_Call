import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:video_call/const/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  _CamScreenState createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  RtcEngine? engine;  // 아고라 엔진을 저장할 변수
  int? uid;           // 내 ID
  int? otherUid;      // 상대방 ID

  Future<bool> init() async {   // 권한 관련 작업 모두 실행
    final resp = await [Permission.camera, Permission.microphone].request();

    final cameraPermission = resp[Permission.camera];
    final micPermission = resp[Permission.microphone];

    if (cameraPermission != PermissionStatus.granted ||
        micPermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다';
    }

    if (engine == null) {
      // 엔진이 정의되지 않았으면 새로 정의하기
      engine = createAgoraRtcEngine();

      // 아고라 엔진 초기화
      await engine!.initialize(
        // 초기화할 때 사용할 설정 제공
        RtcEngineContext(
          // 미리 저장해둔 APP ID 입력
          appId : APP_ID,
          // 라이브 동영상 송출에 최적화
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      engine!.registerEventHandler(
        // 아고라 엔진에서 받을 수 있는 이벤트 값들 등록
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            // 채널 접속에 성공했을 때 실행
            print('채널에 입장했습니다. uid : ${connection.localUid}');
            setState((){
              this.uid = connection.localUid;
            });
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            // 채널을 퇴장했을 때 실행
            print('채널 퇴장');
            setState((){
              uid = null;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            // 다른 사용자가 접속했을 때 실행
            print('상대가 채널에 입장했습니다. uid : ${remoteUid}');
            setState((){
              otherUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            // 다른 사용자가 채널을 나갔을 때 실행
            print('상대가 채널에서 나갔습니다. uid : $uid');
            setState((){
              otherUid = null;
            });
          },
        ),
      );

      // 엔진으로 영상을 송출하겠다고 설정
      await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine!.enableVideo();    // 동영상 기능 활성화
      await engine!.startPreview();   // 카메라를 이용해 동영상을 화면에 실행
      // 채널에 들어가기
      await engine!.joinChannel(
        // 8. 채널 입장하기
        token: TEMP_TOKEN,
        channelId: CHANNEL_NAME,

        // 영상과 관련된 여러 가지 설정 가능
        // 현재 프로젝트에서는 불필요
        options: ChannelMediaOptions(),
        uid: 0,
      );
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold (
      appBar: AppBar(
        title: Text('LIVE'),
      ),
      body: FutureBuilder(    // Future 값을 기반으로 위젯 렌더링
        future: init(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if(snapshot.hasError){  // Future 실행 후 에러가 있을 때
            return Center(
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }

          if(!snapshot.hasData){  // Future 실행 후 아직 데이터가 없을 때 (로딩 중)
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          // return Center(  // 나머지 상황에 권한 있음을 표시
          //   child: Text('모든 권한이 있습니다'),
          // );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    renderMainView(), // 상대방이 찍는 화면
                    Align(    // 내가 찍는 화면
                      alignment: Alignment.topLeft, // 왼쪽 위에 위치
                      child: Container(
                        color: Colors.grey,
                        height: 160,
                        width: 120,
                        child: renderSubView(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(  // 뒤로 가기 기능 및 채널 퇴장 기능
                  onPressed: () async {
                    if(engine != null){
                      await engine!.leaveChannel();
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text('채널 나가기'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 내 핸드폰이 찍는 화면 렌더링
  Widget renderSubView(){
    if(uid != null) {
      // AgoraVideoView 위젯을 사용하면 동영상을 화면에 보여주는 위젯 구현 가능
      return AgoraVideoView(
        // VideoViewController 를 매개변수로 입력해주면 해당 컨트롤러가 제공하는 동영상 정보를
        // AgoraVideoView 위젯을 통해 보여줄 수 있음
        controller: VideoViewController(
          rtcEngine: engine!,
          // VideoCanvas 에 0 을 입력해서 내 영상을 보여줌
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      // 아직 내가 채널에 접속하지 않았다면 로딩 화면을 보여줌
      return CircularProgressIndicator();
    }
  }

  Widget renderMainView() {   // 상대 핸드폰이 찍는 화면 렌더링
    if (otherUid != null) {
      return AgoraVideoView(
        // VideoViewController.remote 생성자를 이용하면
        // 상대방의 동영상을 AgoraVideoView 그려낼 수 있음
        controller: VideoViewController.remote(
          rtcEngine: engine!,
          // uid 에 상대방 ID 입력
          canvas: VideoCanvas(uid: otherUid),
          connection: const RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    } else {
      // 상대가 아직 채널에 들어오지 않았다면 대기 메시지를 보여줌
      return Center(
        child: const Text(
          '다른 사용자가 입장할 때까지 대기해주세요',
          textAlign: TextAlign.center,
        ),
      );
    }
  }
}