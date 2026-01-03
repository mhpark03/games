import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'number_pad.dart';

/// 일반 스도쿠와 사무라이 스도쿠에서 공통으로 사용하는 게임 컨트롤 패널
class GameControlPanel extends StatefulWidget {
  /// 숫자 탭 콜백 (isNoteMode 포함)
  final void Function(int number, bool isNoteMode) onNumberTap;

  /// 지우기 콜백 (선택된 셀 지우기)
  final VoidCallback onErase;

  /// 취소(Undo) 콜백
  final VoidCallback onUndo;

  /// 취소 가능 여부
  final bool canUndo;

  /// 힌트 콜백
  final VoidCallback onHint;

  /// 모든 메모 채우기 콜백
  final VoidCallback onFillAllNotes;

  /// 빠른 입력 모드 변경 콜백
  final void Function(bool isQuickInputMode, int? quickInputNumber)? onQuickInputModeChanged;

  /// 메모 모드 변경 콜백
  final void Function(bool isNoteMode)? onNoteModeChanged;

  /// 지우기 모드 변경 콜백
  final void Function(bool isEraseMode)? onEraseModeChanged;

  /// 비활성화할 숫자들 (9개 모두 채워진 숫자)
  final Set<int> disabledNumbers;

  /// 컴팩트 모드 (가로 모드)
  final bool isCompact;

  /// 외부에서 빠른 입력 모드 초기값 설정
  final bool initialQuickInputMode;

  /// 외부에서 빠른 입력 숫자 초기값 설정
  final int? initialQuickInputNumber;

  /// 외부에서 메모 모드 초기값 설정
  final bool initialNoteMode;

  /// 가로 모드에서 화면 높이 (동적 크기 계산용)
  final double? landscapeHeight;

  const GameControlPanel({
    super.key,
    required this.onNumberTap,
    required this.onErase,
    required this.onUndo,
    this.canUndo = false,
    required this.onHint,
    required this.onFillAllNotes,
    required this.disabledNumbers,
    this.onQuickInputModeChanged,
    this.onNoteModeChanged,
    this.onEraseModeChanged,
    this.isCompact = false,
    this.initialQuickInputMode = false,
    this.initialQuickInputNumber,
    this.initialNoteMode = false,
    this.landscapeHeight,
  });

  @override
  State<GameControlPanel> createState() => GameControlPanelState();
}

class GameControlPanelState extends State<GameControlPanel> {
  late bool _isQuickInputMode;
  int? _quickInputNumber;
  late bool _isNoteMode;
  bool _isEraseMode = false;

  bool get isQuickInputMode => _isQuickInputMode;
  int? get quickInputNumber => _quickInputNumber;
  bool get isNoteMode => _isNoteMode;
  bool get isEraseMode => _isEraseMode;

  @override
  void initState() {
    super.initState();
    _isQuickInputMode = widget.initialQuickInputMode;
    _quickInputNumber = widget.initialQuickInputNumber;
    _isNoteMode = widget.initialNoteMode;
  }

  @override
  void didUpdateWidget(GameControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 빠른 입력 모드에서 선택된 숫자가 비활성화되면 다음 활성화된 숫자 자동 선택
    if (_isQuickInputMode && _quickInputNumber != null) {
      if (widget.disabledNumbers.contains(_quickInputNumber)) {
        // 다음 활성화된 숫자 찾기
        int? nextNumber = _findNextActiveNumber(_quickInputNumber!);
        if (nextNumber != _quickInputNumber) {
          // 빌드 완료 후 setState 호출
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _quickInputNumber = nextNumber;
              });
              widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
            }
          });
        }
      }
    }
  }

  /// 다음 활성화된 숫자 찾기 (현재 숫자부터 순환)
  int? _findNextActiveNumber(int currentNumber) {
    // 현재 숫자 다음부터 9까지 확인
    for (int i = currentNumber + 1; i <= 9; i++) {
      if (!widget.disabledNumbers.contains(i)) {
        return i;
      }
    }
    // 1부터 현재 숫자 전까지 확인
    for (int i = 1; i < currentNumber; i++) {
      if (!widget.disabledNumbers.contains(i)) {
        return i;
      }
    }
    // 모든 숫자가 비활성화된 경우
    return null;
  }

  /// 빠른 입력 모드 토글
  void toggleQuickInputMode() {
    setState(() {
      _isQuickInputMode = !_isQuickInputMode;
      if (!_isQuickInputMode) {
        _quickInputNumber = null;
      }
      // 빠른 입력 모드 켜면 지우기 모드 끄기
      if (_isQuickInputMode) {
        _isEraseMode = false;
        widget.onEraseModeChanged?.call(_isEraseMode);
      }
    });
    widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
  }

  /// 메모 모드 토글
  void toggleNoteMode() {
    setState(() {
      _isNoteMode = !_isNoteMode;
      // 빠른 입력과 메모 모드 동시 선택 가능
    });
    widget.onNoteModeChanged?.call(_isNoteMode);
  }

  /// 지우기 모드 토글
  void toggleEraseMode() {
    setState(() {
      _isEraseMode = !_isEraseMode;
      // 지우기 모드 켜면 빠른 입력 모드 끄기
      if (_isEraseMode) {
        _isQuickInputMode = false;
        _quickInputNumber = null;
        widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
      }
    });
    widget.onEraseModeChanged?.call(_isEraseMode);
  }

  /// 빠른 입력 숫자 선택
  void selectQuickInputNumber(int? number) {
    setState(() {
      _quickInputNumber = number;
    });
    widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
  }

  /// 빠른 입력 모드 해제
  void clearQuickInputMode() {
    setState(() {
      _isQuickInputMode = false;
      _quickInputNumber = null;
    });
    widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
  }

  /// 지우기 모드 해제
  void clearEraseMode() {
    setState(() {
      _isEraseMode = false;
    });
    widget.onEraseModeChanged?.call(_isEraseMode);
  }

  void _onNumberTap(int number) {
    if (_isQuickInputMode) {
      // 빠른 입력 모드: 숫자 선택/해제
      setState(() {
        if (_quickInputNumber == number) {
          _quickInputNumber = null;
        } else {
          _quickInputNumber = number;
        }
      });
      widget.onQuickInputModeChanged?.call(_isQuickInputMode, _quickInputNumber);
    } else {
      // 일반 모드: 상위 위젯에 전달
      widget.onNumberTap(number, _isNoteMode);
    }
  }

  // 화면 높이에 따른 크기 계수 계산
  double _getSizeFactor() {
    if (!widget.isCompact || widget.landscapeHeight == null) return 0.0;
    return ((widget.landscapeHeight! - 300) / 300).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      final bool showModeGuide = _isQuickInputMode || _isEraseMode;
      // 화면 높이에 따른 동적 크기 계산 (가로 모드)
      final sectionSpacing = 8.0 + (_getSizeFactor() * 8.0); // 8~16

      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showModeGuide) _buildModeGuide(),
            SizedBox(height: showModeGuide ? 4 : 6),
            _buildControlButtons(),
            SizedBox(height: sectionSpacing),
            NumberPad(
              onNumberTap: _onNumberTap,
              onUndo: widget.onUndo,
              canUndo: widget.canUndo,
              isCompact: true,
              quickInputNumber: _isQuickInputMode ? _quickInputNumber : null,
              onQuickInputToggle: null,
              disabledNumbers: widget.disabledNumbers,
              showUndoButton: false, // 컨트롤 버튼에 취소 버튼이 있으므로 숨김
              landscapeHeight: widget.landscapeHeight,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isQuickInputMode || _isEraseMode) _buildModeGuide(),
        _buildControlButtons(),
        SizedBox(height: widget.isCompact ? 10 : 14),
        NumberPad(
          onNumberTap: _onNumberTap,
          onUndo: widget.onUndo,
          canUndo: widget.canUndo,
          isCompact: widget.isCompact,
          quickInputNumber: _isQuickInputMode ? _quickInputNumber : null,
          onQuickInputToggle: null,
          disabledNumbers: widget.disabledNumbers,
        ),
      ],
    );
  }

  Widget _buildModeGuide() {
    String guideText;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (_isEraseMode) {
      guideText = 'games.sudoku.eraseMode'.tr();
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade700;
    } else if (_isQuickInputMode && _isNoteMode) {
      guideText = _quickInputNumber != null
          ? 'games.sudoku.quickInputNoteGuide'.tr(namedArgs: {'num': '$_quickInputNumber'})
          : 'games.sudoku.selectNumber'.tr();
      bgColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      textColor = Colors.amber.shade700;
    } else {
      guideText = _quickInputNumber != null
          ? 'games.sudoku.quickInputGuide'.tr(namedArgs: {'num': '$_quickInputNumber'})
          : 'games.sudoku.selectNumber'.tr();
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade700;
    }

    final sizeFactor = _getSizeFactor();
    final hPadding = widget.isCompact ? (8.0 + sizeFactor * 4.0) : 12.0;
    final vPadding = widget.isCompact ? (3.0 + sizeFactor * 3.0) : 6.0;
    final iconSz = widget.isCompact ? (12.0 + sizeFactor * 4.0) : 16.0;
    final fontSz = widget.isCompact ? (10.0 + sizeFactor * 2.0) : 12.0;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isCompact ? 2 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: hPadding,
        vertical: vPadding,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isEraseMode ? Icons.cleaning_services : Icons.info_outline,
            size: iconSz,
            color: textColor,
          ),
          SizedBox(width: widget.isCompact ? 3 : 6),
          Flexible(
            child: Text(
              guideText,
              style: TextStyle(
                fontSize: fontSz,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    final sizeFactor = _getSizeFactor();
    final spacing = widget.isCompact ? (4.0 + sizeFactor * 4.0) : 8.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        _buildToggleButton(
          icon: Icons.flash_on,
          label: 'games.sudoku.quickInput'.tr(),
          isActive: _isQuickInputMode,
          activeColor: Colors.orange,
          onTap: toggleQuickInputMode,
        ),
        _buildToggleButton(
          icon: Icons.edit_note,
          label: 'games.sudoku.notes'.tr(),
          isActive: _isNoteMode,
          activeColor: Colors.amber,
          onTap: toggleNoteMode,
        ),
        _buildFeatureButton(
          icon: Icons.grid_on,
          label: 'games.sudoku.fillNotes'.tr(),
          onTap: widget.onFillAllNotes,
        ),
        _buildToggleButton(
          icon: Icons.cleaning_services,
          label: 'games.sudoku.erase'.tr(),
          isActive: _isEraseMode,
          activeColor: Colors.red,
          onTap: toggleEraseMode,
        ),
        _buildFeatureButton(
          icon: Icons.lightbulb_outline,
          label: 'common.hint'.tr(),
          onTap: widget.onHint,
          color: Colors.deepOrange,
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final sizeFactor = _getSizeFactor();
    final hPadding = widget.isCompact ? (8.0 + sizeFactor * 6.0) : 14.0;
    final vPadding = widget.isCompact ? (4.0 + sizeFactor * 3.0) : 7.0;
    final iconSz = widget.isCompact ? (12.0 + sizeFactor * 5.0) : 17.0;
    final fontSz = widget.isCompact ? (10.0 + sizeFactor * 3.0) : 13.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hPadding,
          vertical: vPadding,
        ),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSz,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            SizedBox(width: widget.isCompact ? 3 : 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: fontSz,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final sizeFactor = _getSizeFactor();
    final hPadding = widget.isCompact ? (8.0 + sizeFactor * 6.0) : 14.0;
    final vPadding = widget.isCompact ? (4.0 + sizeFactor * 3.0) : 7.0;
    final iconSz = widget.isCompact ? (12.0 + sizeFactor * 5.0) : 17.0;
    final fontSz = widget.isCompact ? (10.0 + sizeFactor * 3.0) : 13.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hPadding,
          vertical: vPadding,
        ),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSz, color: color ?? Colors.blue),
            SizedBox(width: widget.isCompact ? 3 : 6),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.blue,
                fontWeight: FontWeight.w500,
                fontSize: fontSz,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
