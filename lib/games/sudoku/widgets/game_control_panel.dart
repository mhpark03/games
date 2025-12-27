import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isQuickInputMode || _isEraseMode) _buildModeGuide(),
            const SizedBox(height: 8),
            _buildControlButtons(),
            const SizedBox(height: 16),
            NumberPad(
              onNumberTap: _onNumberTap,
              onUndo: widget.onUndo,
              canUndo: widget.canUndo,
              isCompact: true,
              quickInputNumber: _isQuickInputMode ? _quickInputNumber : null,
              onQuickInputToggle: null,
              disabledNumbers: widget.disabledNumbers,
              showUndoButton: false, // 컨트롤 버튼에 취소 버튼이 있으므로 숨김
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_isQuickInputMode || _isEraseMode) _buildModeGuide(),
        _buildControlButtons(),
        const SizedBox(height: 16),
        NumberPad(
          onNumberTap: _onNumberTap,
          onUndo: widget.onUndo,
          canUndo: widget.canUndo,
          isCompact: false,
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
      guideText = '지우기 모드 - 셀을 탭하여 지우기';
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade700;
    } else if (_isQuickInputMode && _isNoteMode) {
      guideText = _quickInputNumber != null
          ? '숫자 $_quickInputNumber 선택됨 - 셀 탭→메모'
          : '아래에서 숫자를 먼저 선택하세요';
      bgColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      textColor = Colors.amber.shade700;
    } else {
      guideText = _quickInputNumber != null
          ? '숫자 $_quickInputNumber 선택됨 - 셀 탭→입력'
          : '아래에서 숫자를 먼저 선택하세요';
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isEraseMode ? Icons.cleaning_services : Icons.info_outline,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              guideText,
              style: TextStyle(
                fontSize: 12,
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
    return Wrap(
      spacing: widget.isCompact ? 6 : 8,
      runSpacing: widget.isCompact ? 6 : 8,
      alignment: WrapAlignment.center,
      children: [
        _buildToggleButton(
          icon: Icons.flash_on,
          label: '빠른',
          isActive: _isQuickInputMode,
          activeColor: Colors.orange,
          onTap: toggleQuickInputMode,
        ),
        _buildToggleButton(
          icon: Icons.edit_note,
          label: '메모',
          isActive: _isNoteMode,
          activeColor: Colors.amber,
          onTap: toggleNoteMode,
        ),
        _buildFeatureButton(
          icon: Icons.grid_on,
          label: '모든 메모',
          onTap: widget.onFillAllNotes,
        ),
        _buildToggleButton(
          icon: Icons.cleaning_services,
          label: '지우기',
          isActive: _isEraseMode,
          activeColor: Colors.red,
          onTap: toggleEraseMode,
        ),
        _buildFeatureButton(
          icon: Icons.lightbulb_outline,
          label: '힌트',
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCompact ? 12 : 16,
          vertical: widget.isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: widget.isCompact ? 16 : 18,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: widget.isCompact ? 12 : 14,
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isCompact ? 12 : 16,
          vertical: widget.isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: widget.isCompact ? 16 : 18, color: color ?? Colors.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.blue,
                fontWeight: FontWeight.w500,
                fontSize: widget.isCompact ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
