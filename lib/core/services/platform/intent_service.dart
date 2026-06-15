import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

class IntentService {
  Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<bool> openFile(String filePath) async {
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  }
}
