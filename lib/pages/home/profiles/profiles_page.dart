import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../enums/video_orientation.dart';
import '../../../models/profile.dart';
import '../../../utils/app_paths.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/delete_confirmation_dialog.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/theme.dart';
import '../../../utils/utils.dart';
import 'widgets/new_profile_sheet.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final String logTag = '[PROFILES PAGE] - ';
  int groupValue = 0;

  late final bool isDarkTheme = ThemeService().isDarkTheme();

  // Cycled through by list position, so each profile's avatar is easy to
  // tell apart at a glance.
  static const List<Color> _accentColors = [
    AppColors.mainColor,
    AppColors.green,
    AppColors.purple,
    AppColors.yellow,
    AppColors.orange,
  ];

  List<Profile> profiles = [];

  final DailyEntryController dailyEntryController = Get.find();

  @override
  void initState() {
    super.initState();
    validateProfileList();
    setSelectedProfileIndex();
  }

  void validateProfileList() {
    // Get profiles from persistence
    List<String>? storedProfiles = SharedPrefsUtil.getStringList('profiles');

    if (storedProfiles == null || storedProfiles.isEmpty) {
      // Add the default profile to storage
      storedProfiles = ['Default'];
      SharedPrefsUtil.putStringList('profiles', storedProfiles);
    }

    // Check if the 'Default' profile already exists in storage, otherwise add it
    if (!storedProfiles.contains('Default')) {
      profiles.insert(
        0,
        Profile(
          label: 'Default',
          isDefault: true,
          orientation: StorageUtils.getOrientation(''),
        ),
      );
    } else {
      profiles = storedProfiles.map((e) {
        // The Default profile's storage key is '' everywhere else in the
        // app (AppPaths.profileVideos, Utils.getCurrentProfile) — match it
        // here so its orientation is looked up under the same key.
        final String orientationKey = e == 'Default' ? '' : e;
        final VideoOrientation orientation = StorageUtils.getOrientation(
          orientationKey,
        );
        if (e == 'Default') {
          return Profile(label: e, isDefault: true, orientation: orientation);
        }
        return Profile(label: e, orientation: orientation);
      }).toList();
    }

    Utils.logInfo('${logTag}Stored Profiles are: $storedProfiles');
  }

  void setSelectedProfileIndex() {
    groupValue = SharedPrefsUtil.getInt('selectedProfileIndex') ?? 0;
  }

  Future<void> _createProfile() async {
    final NewProfileRequest? request = await NewProfileSheet.show(
      context,
      existingLabels: profiles.map((profile) => profile.label).toList(),
    );
    if (request == null) return;

    // Create the profile directory for the new profile
    await StorageUtils.createSpecificProfileFolder(request.name);
    await StorageUtils.setOrientation(request.name, request.orientation);

    Utils.logInfo(
      '${logTag}Profile ${request.name} created as ${request.orientation.name}!',
    );

    // Add the new profile to the end of the list
    setState(() {
      profiles.add(
        Profile(label: request.name, orientation: request.orientation),
      );
    });
    _persistProfiles();
  }

  Future<void> _deleteProfile(int index) async {
    final bool confirmed = await DeleteConfirmationDialog.show(
      context,
      titleKey: 'deleteProfile',
      messageKey: 'deleteProfileTooltip',
    );
    if (!confirmed) return;

    final String label = profiles[index].label;

    // Delete the profile directory for the specific profile
    await StorageUtils.deleteSpecificProfileFolder(label);

    Utils.logWarning('${logTag}Profile $label deleted!');

    setState(() => profiles.removeAt(index));
    _persistProfiles();

    if (index == groupValue) {
      // The selected profile is gone, fall back to Default
      _selectProfile(0);
    } else if (index < groupValue) {
      // The selected profile moved up one slot, keep it selected
      _selectProfile(groupValue - 1);
    }
  }

  void _persistProfiles() {
    SharedPrefsUtil.putStringList(
      'profiles',
      profiles.map((e) => e.label).toList(),
    );
  }

  void _selectProfile(int index) {
    // Set index in UI
    setState(() => groupValue = index);

    // Set index in persistence
    SharedPrefsUtil.putInt('selectedProfileIndex', index);

    // Updates everything related to the profile
    updateAppProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'profiles'.tr,
          style: const TextStyle(fontFamily: 'Magic', color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _hint();
                final int profileIndex = index - 1;
                return _ProfileCard(
                  profile: profiles[profileIndex],
                  accentColor:
                      _accentColors[profileIndex % _accentColors.length],
                  selected: profileIndex == groupValue,
                  isDark: isDarkTheme,
                  onTap: () {
                    if (profileIndex == groupValue) return;
                    HapticFeedback.selectionClick();
                    _selectProfile(profileIndex);
                  },
                  onDelete: profiles[profileIndex].isDefault
                      ? null
                      : () => _deleteProfile(profileIndex),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _createProfile,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'createNewProfile'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hint() {
    final Color mutedTextColor = isDarkTheme ? Colors.white60 : Colors.black54;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 18, color: mutedTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'tapToSwitch'.tr,
              style: TextStyle(fontSize: 14, color: mutedTextColor),
            ),
          ),
        ],
      ),
    );
  }

  // Updates the calendar, video count card and daily recording status
  void updateAppProfile() {
    // Update the video count card
    Utils.updateVideoCount();

    Utils.logInfo('${logTag}Selected Profile changed!');

    // Update daily entry
    final String today = DateFormatUtils.getToday();
    final String profile = Utils.getCurrentProfile();
    final String todaysVideoPath =
        '${AppPaths.profileVideos(profile)}$today.mp4';
    final bool isTodayRecorded = StorageUtils.checkFileExists(todaysVideoPath);
    if (isTodayRecorded) {
      Utils.logInfo(
        '$logTag$todaysVideoPath exists, setting today status to recorded.',
      );
      dailyEntryController.updateDaily();
    } else {
      Utils.logInfo(
        '$logTag$todaysVideoPath does not exist, setting today status to not recorded.',
      );
      dailyEntryController.updateDaily(value: false);
    }
  }
}

/// One profile in the list: an avatar, its name and orientation, the
/// selected check and a delete button (every profile but Default).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.accentColor,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  final Profile profile;
  final Color accentColor;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  bool get _isLandscape => profile.orientation == VideoOrientation.landscape;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : AppColors.dark;
    final Color mutedTextColor = isDark ? Colors.white60 : Colors.black54;
    final Color cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final String label = profile.isDefault ? 'default'.tr : profile.label;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                AppColors.mainColor.withValues(alpha: isDark ? 0.14 : 0.08),
                cardColor,
              )
            : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.mainColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, onDelete == null ? 16 : 6, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: profile.isDefault
                      ? Icon(Icons.home_rounded, color: accentColor, size: 22)
                      : Text(
                          label.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _isLandscape
                                ? Icons.stay_current_landscape_rounded
                                : Icons.stay_current_portrait_rounded,
                            size: 15,
                            color: mutedTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isLandscape ? 'landscape'.tr : 'portrait'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.mainColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'deleteProfile'.tr,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: mutedTextColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
