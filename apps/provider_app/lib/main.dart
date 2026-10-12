import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppBootstrap(config: loadAppConfig()));
}
