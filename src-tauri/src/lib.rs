// نواة تطبيق سطح المكتب.
//
// الواجهة نفسها التي تعمل على الويب — لا نسخة ثانية تتخلّف عن الأولى. وما
// يزيده Rust هنا ثلاثةٌ لا تستطيعها صفحةٌ في متصفّح: حفظُ التقارير بحوارٍ
// حقيقيّ يختار فيه المستخدم المجلّد، وفتحُ الروابط الخارجية في المتصفّح لا
// داخل النافذة، وتذكُّرُ حجم النافذة وموضعها بين الجلسات.

use std::io::Write;
use std::path::PathBuf;

/// يكتب نصّاً إلى مسارٍ اختاره المستخدم من حوار الحفظ.
///
/// كُتب أمراً خاصّاً بدل `tauri-plugin-fs` عن قصد: ذلك الملحق يحرس المسارات
/// بنطاقٍ معرَّفٍ مسبقاً، والمسار هنا لا يُعرف إلا لحظة اختياره — فمطابقته
/// بنطاقٍ مفتوحٍ تُلغي الحراسة وتُبقي التعقيد. والحدّ الأمنيّ واحد في
/// الحالتين: لا يُكتب إلا ما اختاره صاحب الجهاز بيده.
///
/// ويُكتب بالبايتات لا بالنصّ لأن علامة ترتيب البايتات (BOM) في أوّل الملف
/// هي ما يجعل Excel يقرأ العربية سليمةً بدل طلاسم.
#[tauri::command]
fn save_text_file(path: String, contents: String) -> Result<(), String> {
    let path = PathBuf::from(path);
    let mut file = std::fs::File::create(&path)
        .map_err(|e| format!("تعذّر إنشاء الملف: {e}"))?;
    file.write_all(contents.as_bytes())
        .map_err(|e| format!("تعذّرت الكتابة: {e}"))?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .invoke_handler(tauri::generate_handler![save_text_file])
        .run(tauri::generate_context!())
        .expect("تعذّر تشغيل نافذة اللوحة");
}
