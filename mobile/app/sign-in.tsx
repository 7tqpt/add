import { useState } from 'react'
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, View } from 'react-native'
import { useRouter } from 'expo-router'
import { SafeAreaView } from 'react-native-safe-area-context'
import { Body, Button, Card, Input, Screen, Title } from '@/ui/kit'
import { useSession } from '@/lib/session'
import { colors, space, text } from '@/lib/theme'
import { messageOf } from '@/lib/useAsync'

export default function SignIn() {
  const { signIn, signUp } = useSession()
  const router = useRouter()
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit() {
    if (!email.trim() || !password) {
      setError('اكتب البريد وكلمة المرور.')
      return
    }
    setError(null)
    setBusy(true)
    try {
      if (mode === 'signin') await signIn(email.trim(), password)
      else await signUp(email.trim(), password)
      router.replace('/')
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Screen>
      <SafeAreaView style={{ flex: 1 }}>
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.lg, flexGrow: 1, justifyContent: 'center' }}>
            <View style={{ alignItems: 'center', gap: space.xs }}>
              <Text style={{ fontSize: 30 }}>💍</Text>
              <Title>أعراس اليمن</Title>
              <Text style={[text.small, { textAlign: 'center' }]}>
                {mode === 'signin'
                  ? 'سجّل الدخول لمتابعة حجوزاتك'
                  : 'أنشئ حسابك لتبدأ تجهيز عرسك'}
              </Text>
            </View>

            <Card>
              <Input
                label="البريد الإلكتروني"
                value={email}
                onChangeText={setEmail}
                autoCapitalize="none"
                keyboardType="email-address"
                textContentType="emailAddress"
                textAlign="left"
                placeholder="you@example.com"
              />
              <Input
                label="كلمة المرور"
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                textAlign="left"
                placeholder="••••••••"
                hint={mode === 'signup' ? 'ثمانية أحرف فأكثر.' : undefined}
              />

              {error ? (
                <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>
                  {error}
                </Text>
              ) : null}

              <Button
                label={mode === 'signin' ? 'دخول' : 'إنشاء الحساب'}
                onPress={submit}
                busy={busy}
              />

              <Pressable
                onPress={() => {
                  setMode(mode === 'signin' ? 'signup' : 'signin')
                  setError(null)
                }}
                style={{ paddingVertical: space.sm }}
              >
                <Text style={[text.small, { textAlign: 'center', color: colors.accent }]}>
                  {mode === 'signin' ? 'ما عندي حساب — أنشئ واحداً' : 'عندي حساب — سجّل الدخول'}
                </Text>
              </Pressable>
            </Card>

            <Body>
              التطبيق للعملاء ومقدّمي الخدمة معاً. تختار دورك بعد التسجيل، وتبدّله متى شئت من
              شاشة حسابك.
            </Body>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Screen>
  )
}
