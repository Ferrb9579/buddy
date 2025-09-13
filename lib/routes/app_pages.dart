import 'package:get/get.dart';
import 'package:buddy/routes/app_routes.dart';
import 'package:buddy/pages/Buddy.dart';
import 'package:buddy/pages/memory_page.dart';

class AppPages {
  static const INITIAL = AppRoutes.BUDDY;

  static final routes = [GetPage(name: AppRoutes.BUDDY, page: () => const Buddy()), GetPage(name: AppRoutes.MEMORY, page: () => const MemoryPage())];
}
