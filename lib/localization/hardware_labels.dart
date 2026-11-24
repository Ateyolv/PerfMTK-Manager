import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:manager/data/models/device_config.dart';
import 'package:manager/localization/app_locales.dart';

/// Display-only labels; leave hardware IDs and serialized values unchanged.
extension LocalizedCpuPolicy on CpuPolicy {
  String localizedClusterName(BuildContext context) => switch (index) {
    0 => AppLocale.littleCluster.getString(context),
    1 => AppLocale.midCluster.getString(context),
    2 => AppLocale.primeCluster.getString(context),
    _ => AppLocale.clusterLabel.getString(context)
        .replaceAll('{index}', index.toString()),
  };
}
