// يمنع نافذةَ الطرفية السوداء التي تُفتح خلف التطبيق في ويندوز عند الإصدار.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    sdd_dashboard_lib::run()
}
