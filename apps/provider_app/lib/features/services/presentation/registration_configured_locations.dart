part of 'registration_option_editor.dart';

/// One independent location group from the service configuration, never a mode picker.
class _ConfiguredLocationEditor extends ConsumerStatefulWidget {
  const _ConfiguredLocationEditor({
    required this.option,
    required this.mode,
    required this.initial,
    required this.loadSavedLocations,
    required this.multiple,
    this.assignmentId,
    super.key,
  });
  final ProviderSchemaOption option;
  final String mode;
  final Map<String, dynamic> initial;
  final bool loadSavedLocations, multiple;
  final int? assignmentId;
  @override
  ConsumerState<_ConfiguredLocationEditor> createState() =>
      _ConfiguredLocationState();
}

class _ConfiguredLocationState
    extends ConsumerState<_ConfiguredLocationEditor> {
  late List<Map<String, dynamic>> areas;
  Map<String, dynamic>? pendingArea;
  final radiusInput = TextEditingController();
  bool loadingAreas = false, areasLoaded = true;
  int areaGeneration = 0;
  String? error;
  String get mode => widget.mode;
  @override
  void initState() {
    super.initState();
    areas = (widget.initial['areas'] as List? ?? [])
        .whereType<Map>()
        .map((area) => Map<String, dynamic>.from(area))
        .toList();
    if (widget.loadSavedLocations &&
        areas.isEmpty &&
        widget.assignmentId != null) {
      areasLoaded = false;
      Future.microtask(loadAreas);
    }
  }

  @override
  void dispose() {
    radiusInput.dispose();
    super.dispose();
  }

  Future<void> loadAreas() async {
    if (!widget.loadSavedLocations || widget.assignmentId == null) {
      return;
    }
    final requestedMode = mode;
    final request = ++areaGeneration;
    setState(() {
      loadingAreas = true;
      areasLoaded = false;
      error = null;
    });
    final result = await ref
        .read(registrationRepositoryProvider)
        .areas(widget.assignmentId!, widget.option.optionId, requestedMode);
    if (!mounted || mode != requestedMode || request != areaGeneration) return;
    setState(() {
      loadingAreas = false;
      if (result is Success<List<Map<String, dynamic>>>) {
        areas = result.value;
        areasLoaded = true;
      } else {
        error = 'Unable to load saved service locations. Please retry.';
      }
    });
  }

  Future<void> location({int? index, bool stage = false}) async {
    final result = await showRegistrationLocation(
      context,
      initial: index == null
          ? {
              'radiusKm': num.tryParse(radiusInput.text),
              if (mode == 'CUSTOMER_TO_PROVIDER')
                'capacity': widget.option.defaultCapacity,
            }
          : areas[index],
      mode: mode,
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null && stage) {
          pendingArea = result;
          radiusInput.text = result['radiusKm']?.toString() ?? '';
        } else if (index == null) {
          areas.add(result);
        } else {
          areas[index] = result;
        }
      });
    }
  }

  void addPendingArea() {
    if (pendingArea == null) {
      location(stage: true);
      return;
    }
    final radius = num.tryParse(radiusInput.text);
    if (mode == 'PROVIDER_TO_CUSTOMER' &&
        (radius == null || !radius.isFinite || radius <= 0)) {
      setState(() => error = 'Enter a positive service radius.');
      return;
    }
    setState(() {
      areas.add({
        ...pendingArea!,
        'radiusKm': mode == 'PROVIDER_TO_CUSTOMER' ? radius : null,
      });
      pendingArea = null;
      error = null;
    });
  }

  bool validate() {
    String? problem;
    if (!areasLoaded || loadingAreas) {
      problem = 'Load your saved locations before replacing them.';
    } else if (pendingArea != null) {
      problem = 'Tap + to add your selected location before saving.';
    } else if (areas.isEmpty) {
      problem = 'Add at least one service location.';
    }
    setState(() => error = problem);
    return problem == null;
  }

  Map<String, dynamic> get snapshot => {'areas': areas};
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RegistrationSection(
        widget.multiple
            ? (mode == 'PROVIDER_TO_CUSTOMER'
                  ? 'Customer coverage areas'
                  : 'Your service locations')
            : 'Service Location & Area',
        !widget.multiple
            ? 'Where do you provide this service?'
            : mode == 'PROVIDER_TO_CUSTOMER'
            ? 'Where can you travel to provide this service?'
            : 'Where do customers visit you?',
        trailing: TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => showRegistrationAreas(context, areas, mode),
          child: registrationText(
            'View in Map',
            11,
            color: const Color(0xFF168EFF),
          ),
        ),
        child: RegistrationPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loadingAreas) const LinearProgressIndicator(),
              if (mode != 'ONLINE') ...[
                for (final (index, area) in areas.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: RegistrationPanel(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: loadingAreas
                                  ? null
                                  : () => location(index: index),
                              child: registrationText(
                                '${area['locationName'] ?? area['city'] ?? ''}',
                                12,
                              ),
                            ),
                          ),
                          if (mode == 'PROVIDER_TO_CUSTOMER' &&
                              area['radiusKm'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F1F8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: registrationText(
                                'Radius: ${area['radiusKm']} km',
                                9,
                                color: registrationMuted,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Remove location',
                            onPressed: loadingAreas
                                ? null
                                : () => setState(() => areas.removeAt(index)),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (areas.isNotEmpty)
                  const Center(
                    child: SizedBox(
                      width: 110,
                      child: Divider(height: 14, thickness: .6),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: loadingAreas
                            ? null
                            : () => location(stage: true),
                        icon: const SizedBox(
                          width: 20,
                          height: 20,
                          child: RegistrationAsset('option_imgLocationPin'),
                        ),
                        label: Row(
                          children: [
                            Expanded(
                              child: registrationText(
                                pendingArea?['locationName'] as String? ??
                                    'Select Location',
                                11,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 17),
                          ],
                        ),
                      ),
                    ),
                    if (mode == 'PROVIDER_TO_CUSTOMER') ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          controller: radiusInput,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'km',
                            suffixText: radiusInput.text.isNotEmpty
                                ? 'km'
                                : null,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 42,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: loadingAreas ? null : addPendingArea,
                        child: const Icon(
                          Icons.add,
                          color: registrationTeal,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                registrationText(
                  'This service is provided online.',
                  12,
                  color: registrationMuted,
                ),
            ],
          ),
        ),
      ),

      if (error != null) RegistrationNotice(error!, warning: true),
      if (!areasLoaded && !loadingAreas)
        TextButton(
          onPressed: loadAreas,
          child: const Text('Retry loading locations'),
        ),
    ],
  );
}
