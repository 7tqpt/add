import { Stack } from 'expo-router'
import { StatusBar } from 'expo-status-bar'
import { I18nManager, Platform } from 'react-native'
import { SafeAreaProvider } from 'react-native-safe-area-context'
import { SessionProvider } from '@/lib/session'
import { colors } from '@/lib/theme'

/**
 * قلب التخطيط لليمين.
 *
 * على الأجهزة يحتاج `forceRTL` إعادةَ تشغيل كاملة ليسري، فتُطلب مرةً واحدة عند
 * الإقلاع. وعلى الويب لا تُطلب: react-native-web يقلب التخطيط بخاصية `dir` في
 * الصفحة، وطلبها هناك يقلبه مرتين فيعود كما كان.
 */
if (Platform.OS !== 'web' && !I18nManager.isRTL) {
  I18nManager.allowRTL(true)
  I18nManager.forceRTL(true)
}

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <SessionProvider>
        <StatusBar style="dark" />
        <Stack
          screenOptions={{
            headerStyle: { backgroundColor: colors.surface },
            headerTintColor: colors.ink,
            headerTitleStyle: { fontWeight: '600' },
            contentStyle: { backgroundColor: colors.page },
          }}
        >
          <Stack.Screen name="index" options={{ headerShown: false }} />
          <Stack.Screen name="sign-in" options={{ headerShown: false }} />
          <Stack.Screen name="onboarding" options={{ title: 'أكمل ملفك' }} />
          <Stack.Screen name="(customer)" options={{ headerShown: false }} />
          <Stack.Screen name="(provider)" options={{ headerShown: false }} />
        </Stack>
      </SessionProvider>
    </SafeAreaProvider>
  )
}
