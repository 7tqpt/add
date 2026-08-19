/**
 * ما يختلف حين تعمل اللوحة برنامجاً على سطح المكتب.
 *
 * الشيفرة واحدة للويب وللمكتب — فرعٌ واحدٌ هنا خيرٌ من نسختين تتباعدان.
 * والاستيرادات كسولة (`await import`) عن قصد: بناءُ الويب لا يجب أن يحمل
 * شيئاً من Tauri، وهي تُطلب فقط داخل الفرع الذي لا يُنفَّذ إلا في البرنامج.
 */

/**
 * هل نحن داخل نافذة Tauri؟
 *
 * القراءة من `__TAURI_INTERNALS__` لا من `navigator.userAgent`: عميلُ
 * المستخدم في WebView2 يطابق Edge حرفاً بحرف، فلا يفرّق. وهذه العلامة
 * يحقنها Tauri نفسه قبل أن يعمل أيُّ سطرٍ من شيفرتنا.
 */
export const isDesktop =
  typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window

/**
 * يحفظ نصّاً في ملفٍّ يختار المستخدم موضعه واسمه.
 *
 * يُرجع `false` إن ألغى المستخدم الحوار — وهو إلغاءٌ لا خطأ، فلا تُعرض له
 * رسالة فشل.
 */
export async function saveTextFile(
  suggestedName: string,
  contents: string,
  filter: { name: string; extensions: string[] },
): Promise<boolean> {
  const { save } = await import('@tauri-apps/plugin-dialog')
  const path = await save({ defaultPath: suggestedName, filters: [filter] })
  if (!path) return false

  const { invoke } = await import('@tauri-apps/api/core')
  await invoke('save_text_file', { path, contents })
  return true
}

/** يفتح رابطاً خارجياً في متصفّح النظام بدل أن يبتلعه إطار البرنامج. */
export async function openExternal(url: string): Promise<void> {
  if (!isDesktop) {
    window.open(url, '_blank', 'noopener,noreferrer')
    return
  }
  const { openUrl } = await import('@tauri-apps/plugin-opener')
  await openUrl(url)
}

/**
 * يُظهر النافذة بعد أن ترسم الواجهة أوّل إطارٍ لها.
 *
 * تبدأ مخفيّة في `tauri.conf.json`، وإلا ظهر إطارٌ أبيض فارغ لجزءٍ من ثانية
 * قبل أن يُحمَّل شيء — وهو أوّل ما يراه المستخدم من البرنامج كلّ مرّة.
 */
export async function revealWindow(): Promise<void> {
  if (!isDesktop) return
  const { getCurrentWindow } = await import('@tauri-apps/api/window')
  const win = getCurrentWindow()
  await win.show()
  await win.setFocus()
}
