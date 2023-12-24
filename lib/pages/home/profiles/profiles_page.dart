import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../models/profile.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/theme.dart';
import '../../../utils/utils.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final String logTag = '[PROFILES PAGE] - ';
  int groupValue = 0;

  final _profileNameController = TextEditingController();
  final _profileNameFormKey = GlobalKey<FormState>();

  final mainColor = ThemeService().isDarkTheme() ? AppColors.dark : AppColors.light;

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
        const Profile(label: 'Default', isDefault: true),
      );
    } else {
      profiles = storedProfiles.map(
        (e) {
          if (e == 'Default') return Profile(label: e, isDefault: true);
          return Profile(label: e);
        },
      ).toList();
    }

    Utils.logInfo('${logTag}Stored Profiles are: $storedProfiles');
  }

  void setSelectedProfileIndex() {
    groupValue = SharedPrefsUtil.getInt('selectedProfileIndex') ?? 0;
  }

  Future<void> _addNewProfileDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Form(
          key: _profileNameFormKey,
          child: AlertDialog(
            title: Text('newProfile'.tr),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'newProfileTooltip'.tr,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _profileNameController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(45),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'profileNameCannotBeEmpty'.tr;
                    }
                    if (!value.contains(RegExp(r'^[\w\d _-]+$'))) {
                      return 'profileNameCannotContainSpecialChars'.tr;
                    }

                    if (value.toLowerCase().trim() == 'default' ||
                        value.toLowerCase().trim() == 'default'.tr.toLowerCase()) {
                      return 'reservedProfileName'.tr;
                    }

                    if (profiles.any(
                        (profile) => profile.label.toLowerCase() == value.toLowerCase().trim())) {
                      return 'profileNameAlreadyExists'.tr;
                    }

                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'enterProfileName'.tr,
                    hintStyle: TextStyle(
                      color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
                    ),
                    errorStyle: const TextStyle(
                      color: AppColors.mainColor,
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.green),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: mainColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.green),
                    ),
                    focusedErrorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.mainColor),
                    ),
                    errorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.mainColor),
                    ),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Checks if the textfield is valid based on if the text passes all the validations we set
                  final bool isTextValid = _profileNameFormKey.currentState?.validate() ?? false;

                  if (isTextValid) {
                    // Create the profile directory for the new profile
                    await StorageUtils.createSpecificProfileFolder(
                      _profileNameController.text.trim(),
                    );

                    Utils.logInfo(
                      '${logTag}Profile ${_profileNameController.text} created!',
                    );

                    // Add the new profile to the end of the list
                    setState(() {
                      profiles.insert(
                        profiles.length,
                        Profile(label: _profileNameController.text.trim()),
                      );
                      _profileNameController.clear();
                    });

                    // Add the modified profile list to persistence
                    final profileNamesToStringList = profiles.map((e) => e.label).toList();
                    SharedPrefsUtil.putStringList('profiles', profileNamesToStringList);

                    Navigator.pop(context);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.green,
                ),
                child: Text('done'.tr),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteProfileDialog(int index) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deleteProfile'.tr),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'deleteProfileTooltip'.tr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: ThemeService().isDarkTheme() ? AppColors.light : AppColors.dark,
            ),
            child: Text(
              'no'.tr,
              style: TextStyle(
                color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Delete the profile directory for the specific profile
              await StorageUtils.deleteSpecificProfileFolder(
                profiles[index].label,
              );

              Utils.logWarning(
                '${logTag}Profile ${profiles[index].label} deleted!',
              );

              // Remove the profile from the list
              setState(() {
                profiles.removeAt(index);
              });

              // Update the profile list in persistence
              final profileNamesToStringList = profiles.map((e) => e.label).toList();
              SharedPrefsUtil.putStringList('profiles', profileNamesToStringList);

              // Select default if the deleted profile was selected
              if (index == groupValue) {
                SharedPrefsUtil.putInt('selectedProfileIndex', 0);
                // Set index in UI
                setState(() {
                  groupValue = 0;
                });
                updateAppProfile();
              }

              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
              'yes'.tr,
              style: TextStyle(
                color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'profiles'.tr,
          style: TextStyle(
            fontFamily: 'Magic',
            fontSize: MediaQuery.of(context).size.width * 0.05,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              Text(
                'tapToSwitch'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.035,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return Material(
                      child: RadioListTile(
                        activeColor: AppColors.green,
                        value: index,
                        groupValue: groupValue,
                        onChanged: (val) {
                          if (val == null) return;

                          // Set index in UI
                          setState(() {
                            groupValue = val;
                          });

                          // Set index in persistence
                          SharedPrefsUtil.putInt('selectedProfileIndex', val);

                          // Updates everything related to the profile
                          updateAppProfile();
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          profiles[index].isDefault ? 'default'.tr : profiles[index].label,
                          style: TextStyle(
                            color: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
                          ),
                        ),
                        secondary: profiles[index].isDefault
                            ? null
                            : IconButton(
                                onPressed: () async {
                                  await _showDeleteProfileDialog(index);
                                },
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  color: AppColors.mainColor,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await _addNewProfileDialog();
                },
                icon: const Icon(Icons.add),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.green,
                ),
                label: Text('createNewProfile'.tr),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Updates the calendar, video count card and daily recording status
  void updateAppProfile() {
    // Update the video count card
    Utils.updateVideoCount();

    Utils.logInfo(
      '${logTag}Selected Profile changed!',
    );

    // Update daily entry
    final String today = DateFormatUtils.getToday();
    final String profile = Utils.getCurrentProfile();
    String todaysVideoPath = SharedPrefsUtil.getString('appPath');
    if (profile.isEmpty) {
      todaysVideoPath = '$todaysVideoPath$today.mp4';
    } else {
      todaysVideoPath = '${todaysVideoPath}Profiles/$profile/$today.mp4';
    }
    final bool isTodayRecorded = StorageUtils.checkFileExists(todaysVideoPath);
    if (isTodayRecorded) {
      Utils.logInfo('$logTag$todaysVideoPath exists, setting today status to recorded.');
      dailyEntryController.updateDaily();
    } else {
      Utils.logInfo(
          '$logTag$todaysVideoPath does not exist, setting today status to not recorded.');
      dailyEntryController.updateDaily(value: false);
    }
  }
}
