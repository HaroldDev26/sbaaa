import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event_result.dart';
import '../../models/team_score.dart';

/// 數據導出服務，提供統計數據導出為PDF功能
class StatisticsExportService {
  /// 導出項目成績數據為PDF
  Future<void> exportEventResultsToPdf({
    required BuildContext context,
    required String competitionName,
    required String eventName,
    required List<EventResult> results,
    required Map<String, dynamic> statistics,
  }) async {
    try {
      // 創建PDF文檔
      final PdfDocument document = PdfDocument();

      // 添加頁面
      final PdfPage page = document.pages.add();

      // 創建PDF網格樣式
      final PdfGridStyle gridStyle = PdfGridStyle(
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
        cellPadding: PdfPaddings(left: 5, right: 5, top: 4, bottom: 4),
      );

      // 繪製標題
      _drawHeader(
        page: page,
        title: '$competitionName - $eventName 成績統計',
      );

      // 繪製統計摘要
      _drawStatisticsSummary(
        page: page,
        statistics: statistics,
        yPosition: 100,
      );

      // 繪製成績表格
      _drawResultsTable(
        page: page,
        results: results,
        yPosition: 200,
        gridStyle: gridStyle,
      );

      // 添加頁碼和頁腳
      _addFooter(document);

      // 保存文件
      final List<int> bytes = await document.save();
      document.dispose();

      // 獲取臨時目錄
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$eventName-results.pdf';

      // 寫入文件
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      // 使用share_plus分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '$competitionName - $eventName 成績統計報告',
      );

      // 顯示成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('成績報告已導出')),
        );
      }
    } catch (e) {
      // 處理錯誤
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('導出失敗: $e')),
        );
      }
    }
  }

  /// 導出隊伍成績為PDF
  Future<void> exportTeamScoresToPdf({
    required BuildContext context,
    required String competitionName,
    required List<TeamScore> teamScores,
  }) async {
    try {
      // 創建PDF文檔
      final PdfDocument document = PdfDocument();

      // 添加頁面
      final PdfPage page = document.pages.add();

      // 創建PDF網格樣式
      final PdfGridStyle gridStyle = PdfGridStyle(
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
        cellPadding: PdfPaddings(left: 5, right: 5, top: 4, bottom: 4),
      );

      // 繪製標題
      _drawHeader(
        page: page,
        title: '$competitionName - 隊伍表現分析',
      );

      // 繪製隊伍統計摘要
      _drawTeamsSummary(
        page: page,
        teamScores: teamScores,
        yPosition: 100,
      );

      // 繪製隊伍排名表格
      _drawTeamsTable(
        page: page,
        teamScores: teamScores,
        yPosition: 180,
        gridStyle: gridStyle,
      );

      // 添加頁碼和頁腳
      _addFooter(document);

      // 保存文件
      final List<int> bytes = await document.save();
      document.dispose();

      // 獲取臨時目錄
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$competitionName-teams.pdf';

      // 寫入文件
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      // 使用share_plus分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '$competitionName - 隊伍表現分析報告',
      );

      // 顯示成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('隊伍分析報告已導出')),
        );
      }
    } catch (e) {
      // 處理錯誤
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('導出失敗: $e')),
        );
      }
    }
  }

  // 繪製頁面標題
  void _drawHeader({
    required PdfPage page,
    required String title,
  }) {
    // 創建頁面圖形和字體
    final PdfGraphics graphics = page.graphics;
    final PdfFont titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont dateFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    // 繪製標題
    graphics.drawString(
      title,
      titleFont,
      brush: PdfSolidBrush(PdfColor(0, 32, 96)),
      bounds: const Rect.fromLTWH(0, 0, 500, 30),
    );

    // 繪製日期
    final DateTime now = DateTime.now();
    final String dateStr =
        '${now.year}年${now.month}月${now.day}日 ${now.hour}:${now.minute}';
    graphics.drawString(
      '生成日期: $dateStr',
      dateFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: const Rect.fromLTWH(0, 30, 500, 20),
    );

    // 繪製分隔線
    graphics.drawLine(
      PdfPen(PdfColor(0, 32, 96), width: 1),
      const Offset(0, 55),
      Offset(page.getClientSize().width, 55),
    );
  }

  // 繪製統計摘要
  void _drawStatisticsSummary({
    required PdfPage page,
    required Map<String, dynamic> statistics,
    required double yPosition,
  }) {
    final PdfGraphics graphics = page.graphics;
    final PdfFont sectionFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont contentFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    // 繪製小節標題
    graphics.drawString(
      '統計摘要',
      sectionFont,
      brush: PdfSolidBrush(PdfColor(0, 32, 96)),
      bounds: Rect.fromLTWH(0, yPosition, page.getClientSize().width, 20),
    );

    // 獲取統計數據
    final int count = statistics['count'] ?? 0;
    final dynamic average = statistics['average'];
    final dynamic min = statistics['min'];
    final dynamic max = statistics['max'];
    final dynamic median = statistics['median'];

    // 構建統計文本
    String statsText = '參賽人數: $count\n';
    if (average != null) statsText += '平均成績: ${average.toStringAsFixed(2)}\n';
    if (min != null)
      statsText +=
          '最佳成績: ${min is int ? _formatTime(min) : min.toStringAsFixed(2)}\n';
    if (max != null)
      statsText +=
          '最低成績: ${max is int ? _formatTime(max) : max.toStringAsFixed(2)}\n';
    if (median != null)
      statsText +=
          '中位數: ${median is int ? _formatTime(median) : median.toStringAsFixed(2)}\n';

    // 繪製統計文本
    graphics.drawString(
      statsText,
      contentFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: Rect.fromLTWH(
          10, yPosition + 25, page.getClientSize().width - 20, 100),
    );
  }

  // 繪製成績表格
  void _drawResultsTable({
    required PdfPage page,
    required List<EventResult> results,
    required double yPosition,
    required PdfGridStyle gridStyle,
  }) {
    // 創建網格
    final PdfGrid grid = PdfGrid();

    // 定義列
    grid.columns.add(count: 5);
    grid.headers.add(1);

    // 設置表頭
    final PdfGridRow header = grid.headers[0];
    header.cells[0].value = '排名';
    header.cells[1].value = '姓名';
    header.cells[2].value = '學校';
    header.cells[3].value = results.first.time != null ? '時間' : '成績';
    header.cells[4].value = '年齡組別';

    // 表頭樣式
    for (int i = 0; i < header.cells.count; i++) {
      header.cells[i].style.backgroundBrush =
          PdfSolidBrush(PdfColor(0, 32, 96));
      header.cells[i].style.textBrush = PdfBrushes.white;
      header.cells[i].style.font = PdfStandardFont(PdfFontFamily.helvetica, 12,
          style: PdfFontStyle.bold);
    }

    // 添加數據行
    for (int i = 0; i < results.length; i++) {
      final EventResult result = results[i];
      final PdfGridRow row = grid.rows.add();

      row.cells[0].value = '${i + 1}';
      row.cells[1].value = result.athleteName;
      row.cells[2].value = result.school ?? '';

      // 根據成績類型顯示時間或分數
      if (result.time != null) {
        row.cells[3].value = _formatTime(result.time!);
      } else if (result.score != null) {
        row.cells[3].value = '${result.score!.toStringAsFixed(2)}';
      } else {
        row.cells[3].value = '-';
      }

      row.cells[4].value = result.ageGroup ?? '';

      // 交替行顏色
      if (i % 2 != 0) {
        for (int j = 0; j < row.cells.count; j++) {
          row.cells[j].style.backgroundBrush =
              PdfSolidBrush(PdfColor(242, 242, 242));
        }
      }
    }

    // 設置網格樣式
    grid.style = gridStyle;

    // 自動調整列寬
    grid.columns[0].width = 40; // 排名
    grid.columns[1].width = 120; // 姓名
    grid.columns[2].width = 150; // 學校
    grid.columns[3].width = 80; // 成績
    grid.columns[4].width = 80; // 年齡組別

    // 繪製網格
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, yPosition, page.getClientSize().width, 0),
    );
  }

  // 繪製隊伍數據摘要
  void _drawTeamsSummary({
    required PdfPage page,
    required List<TeamScore> teamScores,
    required double yPosition,
  }) {
    final PdfGraphics graphics = page.graphics;
    final PdfFont sectionFont =
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final PdfFont contentFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    // 計算總獎牌數和隊伍數
    int totalTeams = teamScores.length;
    int totalGold = 0;
    int totalSilver = 0;
    int totalBronze = 0;

    for (final team in teamScores) {
      totalGold += team.goldMedals;
      totalSilver += team.silverMedals;
      totalBronze += team.bronzeMedals;
    }

    // 繪製小節標題
    graphics.drawString(
      '統計摘要',
      sectionFont,
      brush: PdfSolidBrush(PdfColor(0, 32, 96)),
      bounds: Rect.fromLTWH(0, yPosition, page.getClientSize().width, 20),
    );

    // 構建統計文本
    String statsText = '參賽隊伍數: $totalTeams\n'
        '總金牌數: $totalGold\n'
        '總銀牌數: $totalSilver\n'
        '總銅牌數: $totalBronze\n'
        '總獎牌數: ${totalGold + totalSilver + totalBronze}\n';

    if (teamScores.isNotEmpty) {
      statsText +=
          '排名第一學校: ${teamScores.first.teamName} (總分: ${teamScores.first.totalScore}分)';
    }

    // 繪製統計文本
    graphics.drawString(
      statsText,
      contentFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: Rect.fromLTWH(
          10, yPosition + 25, page.getClientSize().width - 20, 100),
    );
  }

  // 繪製隊伍表格
  void _drawTeamsTable({
    required PdfPage page,
    required List<TeamScore> teamScores,
    required double yPosition,
    required PdfGridStyle gridStyle,
  }) {
    // 創建網格
    final PdfGrid grid = PdfGrid();

    // 定義列
    grid.columns.add(count: 5);
    grid.headers.add(1);

    // 設置表頭
    final PdfGridRow header = grid.headers[0];
    header.cells[0].value = '排名';
    header.cells[1].value = '隊伍名稱';
    header.cells[2].value = '學校';
    header.cells[3].value = '總分';
    header.cells[4].value = '獎牌 (金/銀/銅)';

    // 表頭樣式
    for (int i = 0; i < header.cells.count; i++) {
      header.cells[i].style.backgroundBrush =
          PdfSolidBrush(PdfColor(0, 32, 96));
      header.cells[i].style.textBrush = PdfBrushes.white;
      header.cells[i].style.font = PdfStandardFont(PdfFontFamily.helvetica, 12,
          style: PdfFontStyle.bold);
    }

    // 添加數據行
    for (int i = 0; i < teamScores.length; i++) {
      final TeamScore team = teamScores[i];
      final PdfGridRow row = grid.rows.add();

      row.cells[0].value = '${i + 1}';
      row.cells[1].value = team.teamName;
      row.cells[2].value = team.school ?? '';
      row.cells[3].value = '${team.totalScore}';
      row.cells[4].value =
          '${team.goldMedals}/${team.silverMedals}/${team.bronzeMedals}';

      // 交替行顏色
      if (i % 2 != 0) {
        for (int j = 0; j < row.cells.count; j++) {
          row.cells[j].style.backgroundBrush =
              PdfSolidBrush(PdfColor(242, 242, 242));
        }
      }
    }

    // 設置網格樣式
    grid.style = gridStyle;

    // 自動調整列寬
    grid.columns[0].width = 40; // 排名
    grid.columns[1].width = 120; // 隊伍名稱
    grid.columns[2].width = 150; // 學校
    grid.columns[3].width = 80; // 總分
    grid.columns[4].width = 100; // 獎牌

    // 繪製網格
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, yPosition, page.getClientSize().width, 0),
    );
  }

  // 添加頁腳和頁碼
  void _addFooter(PdfDocument document) {
    for (int i = 0; i < document.pages.count; i++) {
      final PdfPage page = document.pages[i];
      final Size pageSize = page.getClientSize();
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 10);

      // 添加頁碼
      page.graphics.drawString(
        '第 ${i + 1} 頁，共 ${document.pages.count} 頁',
        font,
        brush: PdfBrushes.black,
        bounds:
            Rect.fromLTWH(pageSize.width - 150, pageSize.height - 30, 150, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      // 添加頁腳
      page.graphics.drawString(
        '由校際比賽管理系統生成',
        font,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(0, pageSize.height - 30, 300, 20),
      );
    }
  }

  // 格式化時間 (秒轉換為分:秒.毫秒)
  String _formatTime(int centiseconds) {
    final totalSeconds = centiseconds ~/ 100;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final remainingCentiseconds = centiseconds % 100;

    return '${minutes > 0 ? '$minutes:' : ''}${seconds.toString().padLeft(2, '0')}.${remainingCentiseconds.toString().padLeft(2, '0')}';
  }
}
