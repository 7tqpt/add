import 'react-native-url-polyfill/auto'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { Platform } from 'react-native'

const url = process.env.EXPO_PUBLIC_SUPABASE_URL
const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(url && anonKey)

/**
 * عميل Supabase للتطبيق.
 *
 * المفتاح المستعمل هو publishable/anon، وهو مصمَّم ليعيش في الأجهزة: تطبيقٌ
 * منشور يمكن فكّه واستخراج ما فيه، فالحماية في سياسات RLS لا في إخفاء المفتاح.
 * ولا يوضع `service_role` هنا أبداً — يتجاوز السياسات كلها.
 *
 * `detectSessionInUrl` مطفأة على الأجهزة: لا شريط عنوان فيها، وتفعيلها يجعل
 * المكتبة تنتظر عودةً من المتصفّح لا تأتي.
 */
export const supabase: SupabaseClient | null =
  isSupabaseConfigured && url && anonKey
    ? createClient(url, anonKey, {
        auth: {
          storage: AsyncStorage,
          autoRefreshToken: true,
          persistSession: true,
          detectSessionInUrl: Platform.OS === 'web',
        },
      })
    : null

export function requireSupabase(): SupabaseClient {
  if (!supabase) {
    throw new Error(
      'لم يُضبط Supabase. انسخ .env.example إلى .env واملأ المفتاحين ثم أعد التشغيل.',
    )
  }
  return supabase
}
