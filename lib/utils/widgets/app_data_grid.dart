import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../colors.dart';

/// Definisi kolom tabel — styling sudah di-handle [AppDataGrid].
class AppGridColumn {
  final String field;
  final String title;
  final double width;
  final Alignment align;
  final Alignment? headerAlign;
  final String Function(dynamic value)? format;
  final Widget Function(dynamic value)? cellBuilder;
  final bool isAction;
  final void Function(Map<String, dynamic> rowData)? onActionTap;

  const AppGridColumn(
    this.field,
    this.title, {
    this.width = 140,
    this.align = Alignment.centerLeft,
    this.headerAlign,
    this.format,
    this.cellBuilder,
    this.isAction = false,
    this.onActionTap,
  });
}

/// Tabel SfDataGrid siap pakai: scroll kiri/kanan/atas/bawah + paginasi.
class AppDataGrid extends StatefulWidget {
  final List<AppGridColumn> columns;
  final List<Map<String, dynamic>> rows;
  final int pageSize;
  final SelectionMode selectionMode;
  final void Function(List<DataGridRow> addedRows, List<DataGridRow> removedRows)? onSelectionChanged;
  final EdgeInsetsGeometry margin;
  final void Function(Map<String, dynamic> rowData, String field)? onCellTap;
  final void Function(Map<String, dynamic> rowData)? onActionTap;

  const AppDataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.pageSize = 9,
    this.selectionMode = SelectionMode.single,
    this.onSelectionChanged,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
    this.onCellTap,
    this.onActionTap,
  });

  @override
  State<AppDataGrid> createState() => _AppDataGridState();
}

class _AppDataGridState extends State<AppDataGrid> {
  late _AppDataGridSource _source;

  @override
  void initState() {
    super.initState();
    _source = _AppDataGridSource(
      columns: widget.columns,
      rows: widget.rows,
      pageSize: widget.pageSize,
      onCellTap: widget.onCellTap,
      onActionTap: widget.onActionTap,
    );
  }

  @override
  void didUpdateWidget(AppDataGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update columns (termasuk onActionTap closure terbaru) DAN rows
    _source.updateColumns(widget.columns);
    _source.updateRows(widget.rows);
  }

  double get _pageCount {
    if (widget.rows.isEmpty) return 1;
    return (widget.rows.length / widget.pageSize).ceilToDouble();
  }

  double _pagerBarWidth(BuildContext context) {
    const navButtons = 4;
    const buttonSize = 36.0;
    const extra = 24.0;
    final visiblePages = math.min(_pageCount.ceil(), 5);
    final width = navButtons * buttonSize + visiblePages * buttonSize + extra;
    final maxWidth = MediaQuery.sizeOf(context).width - 40;
    return math.min(width, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              color: colortextwhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffDCE3DF)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SfDataGrid(
                source: _source,
                columns: _gridColumns(widget.columns),
                headerRowHeight: 58,
                rowHeight: 52,
                rowsPerPage: widget.pageSize,
                gridLinesVisibility: GridLinesVisibility.horizontal,
                headerGridLinesVisibility: GridLinesVisibility.horizontal,
                selectionMode: widget.selectionMode,
                onSelectionChanged: widget.onSelectionChanged,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Center(
            child: SizedBox(
              width: _pagerBarWidth(context),
              child: SfDataPager(
                delegate: _source,
                pageCount: _pageCount,
                navigationItemHeight: 36,
                navigationItemWidth: 36,
                itemHeight: 36,
                itemWidth: 36,
                itemPadding: const EdgeInsets.symmetric(horizontal: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<GridColumn> _gridColumns(List<AppGridColumn> columns) {
  return columns
      .map(
        (col) => GridColumn(
          columnName: col.field,
          width: col.width,
          label: Container(
            alignment: col.headerAlign ?? col.align,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: colorPrimaryLight,
              border: Border(right: BorderSide(color: Color(0xffE3E8E5))),
            ),
            child: Text(
              col.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colortextwhite,
              ),
            ),
          ),
        ),
      )
      .toList();
}

class _AppDataGridSource extends DataGridSource {
  _AppDataGridSource({
    required List<AppGridColumn> columns,
    required List<Map<String, dynamic>> rows,
    required this.pageSize,
    this.onCellTap,
    this.onActionTap,
  }) {
    _columns = columns;
    _allRows = rows;
    _loadPage(0);
  }

  late List<AppGridColumn> _columns;
  final int pageSize;
  final void Function(Map<String, dynamic> rowData, String field)? onCellTap;
  final void Function(Map<String, dynamic> rowData)? onActionTap;

  late List<Map<String, dynamic>> _allRows;
  List<DataGridRow> _pageRows = [];

  /// Dipanggil dari didUpdateWidget — pastikan onActionTap closure selalu fresh
  void updateColumns(List<AppGridColumn> columns) {
    _columns = columns;
  }

  void updateRows(List<Map<String, dynamic>> rows) {
    _allRows = rows;
    _loadPage(0);
    notifyDataSourceListeners();
  }

  void _loadPage(int pageIndex) {
    final start = pageIndex * pageSize;
    if (start >= _allRows.length) {
      _pageRows = [];
      return;
    }
    final end = math.min(start + pageSize, _allRows.length);
    _pageRows = _allRows.sublist(start, end).asMap().entries.map((entry) {
      final globalIndex = start + entry.key;
      final item = entry.value;
      return DataGridRow(
        cells: [
          // Cell tersembunyi — menyimpan index absolut ke _allRows
          DataGridCell<int>(columnName: '__rowIndex__', value: globalIndex),
          ..._columns.map((col) => DataGridCell(columnName: col.field, value: item[col.field])),
        ],
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _pageRows;

  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    _loadPage(newPageIndex);
    notifyDataSourceListeners();
    return true;
  }

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final cellsList = row.getCells();

    // Ambil index row asli dari cell tersembunyi, lalu resolve data aslinya
    final rowIndexCell = cellsList.firstWhere((c) => c.columnName == '__rowIndex__');
    final rowIndex = rowIndexCell.value as int;
    final originalRow = _allRows[rowIndex];

    // Filter cell tersembunyi — hanya render kolom yang terlihat
    final visibleCells = cellsList.where((c) => c.columnName != '__rowIndex__').toList();

    return DataGridRowAdapter(
      cells: visibleCells.map((cell) {
        final col = _columns.firstWhere((c) => c.field == cell.columnName);
        const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

        // Kolom aksi — gunakan onActionTap dari kolom (per-kolom) atau fallback widget-level
        if (col.isAction) {
          final tapHandler = col.onActionTap ?? (onActionTap != null ? (Map<String, dynamic> r) => onActionTap!(r) : null);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tapHandler != null ? () => tapHandler(originalRow) : null,
            child: Container(
              alignment: col.align,
              padding: padding,
              child: col.cellBuilder != null
                  ? col.cellBuilder!(cell.value)
                  : const Icon(Icons.more_vert, color: Colors.grey),
            ),
          );
        }

        // Ada cellBuilder (non-action)
        if (col.cellBuilder != null) {
          return Container(
            alignment: col.align,
            padding: padding,
            child: col.cellBuilder!(cell.value),
          );
        }

        // Cell teks biasa
        final text = col.format != null ? col.format!(cell.value) : (cell.value ?? '').toString();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCellTap != null ? () => onCellTap!(originalRow, col.field) : null,
          child: Container(
            alignment: col.align,
            padding: padding,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }
}