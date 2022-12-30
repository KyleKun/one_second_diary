import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/profile.dart';
import '../../../utils/constants.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/theme.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  int groupValue = 0;

  final _profileNameController = TextEditingController();
  final _profileNameFormKey = GlobalKey<FormState>();

  final mainColor = ThemeService().isDarkTheme() ? AppColors.dark : AppColors.light;

  final List<Profile> profiles = [
    const Profile(label: 'Default', isDefault: true),
  ];

  Future<void> _addNewProfileDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Form(
          key: _profileNameFormKey,
          child: AlertDialog(
            title: const Text('New profile'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Creating a new profile will set up a seperate directory for videos created while that profile is selected',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _profileNameController,
                  cursorColor: Colors.green,
                  maxLength: 45,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Profile name cannot be empty';
                    }

                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter profile name',
                    errorStyle: const TextStyle(
                      color: AppColors.mainColor,
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: mainColor),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
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
                  final bool isTextValid =
                      _profileNameFormKey.currentState?.validate() ?? false;

                  if (isTextValid) {
                    // Create the profile directory for the new profile
                    await StorageUtils.createSpecificProfileFolder(
                      _profileNameController.text,
                    );

                    // Add the new profile to the end of the list
                    setState(() {
                      profiles.insert(
                        profiles.length,
                        Profile(label: _profileNameController.text),
                      );
                      _profileNameController.clear();
                    });
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

  Future<void> _showdeleteProfileDialog(int index) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'All videos associated with this profile will also be permanently deleted. Are you sure to continue?',
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
            child: Text('no'.tr),
          ),
          TextButton(
            onPressed: () async {
              // Delete the profile directory for the specific profile
              await StorageUtils.deleteSpecificProfileFolder(
                profiles[index].label,
              );

              // Remove the profile from the list
              setState(() {
                profiles.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('yes'.tr),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profiles',
          style: TextStyle(
            fontFamily: 'Magic',
            fontSize: MediaQuery.of(context).size.width * 0.05,
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
                'Tap on a profile to switch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.035,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return Material(
                      child: RadioListTile(
                        value: index,
                        groupValue: groupValue,
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            groupValue = val;
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(profiles[index].label),
                        secondary: profiles[index].isDefault
                            ? null
                            : IconButton(
                                onPressed: () async {
                                  await _showdeleteProfileDialog(index);
                                },
                                icon: const Icon(
                                  Icons.delete,
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
                  foregroundColor: AppColors.mainColor,
                ),
                label: const Text('Create New Profile'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
