import 'package:flutter/material.dart';

import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';

class JointRotationPanel extends StatelessWidget {
  final JointType selectedJoint;
  final List<JointType> joints;
  final JointRotation rotation;
  final ValueChanged<JointType> onJointSelected;
  final ValueChanged<JointRotation> onChanged;
  final VoidCallback onResetSelected;
  final VoidCallback onResetAll;

  const JointRotationPanel({
    super.key,
    required this.selectedJoint,
    required this.joints,
    required this.rotation,
    required this.onJointSelected,
    required this.onChanged,
    required this.onResetSelected,
    required this.onResetAll,
  });

  @override
  Widget build(BuildContext context) {
    final definition = JointDefinitions.of(selectedJoint);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.accessibility_new,
                color: Color(0xFF4A65FF),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '3D 動作設定（骨骼角度）',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final joint in joints)
                ChoiceChip(
                  key: Key('joint-${joint.name}'),
                  selected: selectedJoint == joint,
                  onSelected: (_) => onJointSelected(joint),
                  label: Text(JointDefinitions.of(joint).displayName),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '左右以人偶本身方向為準；正面觀看時，人偶右側位於畫面左側。\n'
            '紅=X、綠=Y、藍=Z，皆為骨骼 local axes。',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const Key('reset-selected-joint'),
                onPressed: onResetSelected,
                icon: const Icon(Icons.restart_alt, size: 17),
                label: const Text('歸零目前關節'),
              ),
              TextButton.icon(
                key: const Key('reset-all-joints'),
                onPressed: onResetAll,
                icon: const Icon(Icons.settings_backup_restore, size: 17),
                label: const Text('全部歸零'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${definition.displayName}角度',
            key: const Key('selected-joint-title'),
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _RotationSlider(
            key: Key('${selectedJoint.name}-x-slider'),
            valueKey: Key('${selectedJoint.name}-x-value'),
            axis: 'X',
            value: rotation.x,
            range: definition.xRange,
            color: const Color(0xFFE24B4A),
            onChanged: (value) => onChanged(rotation.copyWith(x: value)),
          ),
          _RotationSlider(
            key: Key('${selectedJoint.name}-y-slider'),
            valueKey: Key('${selectedJoint.name}-y-value'),
            axis: 'Y',
            value: rotation.y,
            range: definition.yRange,
            color: const Color(0xFF10B981),
            onChanged: (value) => onChanged(rotation.copyWith(y: value)),
          ),
          _RotationSlider(
            key: Key('${selectedJoint.name}-z-slider'),
            valueKey: Key('${selectedJoint.name}-z-value'),
            axis: 'Z',
            value: rotation.z,
            range: definition.zRange,
            color: const Color(0xFF3B82F6),
            onChanged: (value) => onChanged(rotation.copyWith(z: value)),
          ),
        ],
      ),
    );
  }
}

class _RotationSlider extends StatelessWidget {
  final Key valueKey;
  final String axis;
  final double value;
  final RotationRange range;
  final Color color;
  final ValueChanged<double> onChanged;

  const _RotationSlider({
    super.key,
    required this.valueKey,
    required this.axis,
    required this.value,
    required this.range,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  axis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Container(
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.round()}°',
                  key: valueKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value.clamp(range.min, range.max),
              min: range.min,
              max: range.max,
              divisions: (range.max - range.min).round(),
              label: '${value.round()}°',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
