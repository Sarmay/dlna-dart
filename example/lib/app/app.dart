import 'dart:async';

import 'package:dlna_tv_dart/dlna.dart';
import 'package:dlna_tv_dart/xmlParser.dart';
import 'package:flutter/material.dart';

class DlnaDartDemo extends StatefulWidget {
  const DlnaDartDemo({super.key, this.title = 'Dlna Dart Demo'});

  final String title;

  @override
  State<StatefulWidget> createState() {
    return _DlnaDartDemoState();
  }
}

class _DlnaDartDemoState extends State<DlnaDartDemo> {
  String playUrl = "http://vjs.zencdn.net/v/oceans.mp4";
  final Map<String, DLNADevice> _deviceList = {};
  final DLNAManager searcher = DLNAManager();
  Timer? stopSearchTimer;
  String selectDeviceKey = '';
  bool isSearching = true;
  bool isPlaying = false;
  String playStatus = "STOPPED"; // PLAYING

  DLNADevice? get device => _deviceList[selectDeviceKey];

  bool get isOk => playStatus != "STOPPED";

  @override
  void initState() {
    _startSearch();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    searcher.stop();
    stopSearchTimer?.cancel();
  }

  // 开始搜索
  void _startSearch() async {
    stopSearchTimer?.cancel();
    stopSearchTimer = null;
    // clear old devices
    isPlaying = false;
    playStatus = "STOPPED";
    isSearching = true;
    selectDeviceKey = '';
    _deviceList.clear();
    setState(() {});
    // start search server
    final m = await searcher.start();
    m.devices.stream.listen((deviceList) {
      deviceList.forEach((key, value) {
        _deviceList[key] = value;
      });
      isSearching = false;
      setState(() {});
      if (deviceList.isNotEmpty) {
        searcher.stop();
        stopSearchTimer?.cancel();
      }
    });
    // close the server, the closed server can be start by call searcher.start()
    stopSearchTimer = Timer(const Duration(seconds: 30), () async {
      if (isSearching) {
        setState(() {
          isSearching = false;
        });
        searcher.stop();
      }
    });
  }

  // 选择设备
  void selectDevice(String key) async {
    if (selectDeviceKey.isNotEmpty) device?.pause();
    selectDeviceKey = key;
    // 存储device
    await device?.setUrl(playUrl, title: "视频标题");
    await device?.play();
    isPlaying = true;
    // 等待3秒查询状态
    await Future.delayed(Duration(seconds: 3));
    String? getTransportInfo = await device?.getTransportInfo();
    playStatus = TransportInfoParser(getTransportInfo!).CurrentTransportState;
    if (playStatus == "STOP") {
      // 等待5秒查询状态
      await Future.delayed(Duration(seconds: 5));
      String? getTransportInfo = await device?.getTransportInfo();
      playStatus = TransportInfoParser(getTransportInfo!).CurrentTransportState;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (isSearching && _deviceList.isEmpty) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_deviceList.isEmpty) {
      child = Center(
        child: Text(
          '没有找到设备',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    } else {
      child = ListView(
        shrinkWrap: true,  // 关键属性
        physics: NeverScrollableScrollPhysics(),  // 禁止自身滚动
        children: _deviceList.keys
            .map<Widget>((key) => ListTile(
                  contentPadding: const EdgeInsets.all(2),
                  title: Text(_deviceList[key]!.info.friendlyName),
                  subtitle: Text(key),
                  onTap: () => selectDevice(key),
                ))
            .toList(),
      );
    }

    return MaterialApp(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(
            onPressed: _startSearch,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}
