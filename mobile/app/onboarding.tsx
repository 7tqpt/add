import { useCallback, useState } from 'react'
import { Platform, Pressable, ScrollView, Text, View } from 'react-native'
import { useRouter } from 'expo-router'
import { Body, Button, Card, Empty, Heading, Input, Loading, Screen } from '@/ui/kit'
import { listGovernorates, registerProfile } from '@/lib/api'
import { useSession } from '@/lib/session'
import { useAsync, messageOf } from '@/lib/useAsync'
import { colors, radius, space, text } from '@/lib/theme'

/**
 * إكمال الملف — يُستدعى مرة واحدة بعد أول تسجيل.
 *
 * بلا صفٍّ في `app_users` لا يستطيع الحساب أن يحجز ولا أن يفتح تذكرة: كل دوال
 * الـ API تبدأ بالبحث عنه. فالشاشة ليست ترحيباً تجميلياً بل شرطُ عملٍ.
 */
export default function Onboarding() {
  const router = useRouter()
  const { refresh, signOut } = useSession()
  const load = useCallback(() => listGovernorates(), [])
  const governorates = useAsync(load, [])

  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [governorate, setGovernorate] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit() {
    if (!name.trim() || !phone.trim() || !governorate) {
      setError('اكتب اسمك ورقمك واختر محافظتك.')
      return
    }
    setError(null)
    setBusy(true)
    try {
      await registerProfile({
        fullName: name.trim(),
        phone: phone.trim(),
        governorate,
        platform: Platform.OS === 'ios' ? 'ios' : 'android',
      })
      refresh()
      router.replace('/')
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  if (governorates.loading) {
    return (
      <Screen>
        <Loading />
      </Screen>
    )
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.lg }}>
        <Card>
          <Heading>أهلاً بك</Heading>
          <Body>عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.</Body>

          <Input label="الاسم الكامل" value={name} onChangeText={setName} placeholder="محمد الصنعاني" />
          <Input
            label="رقم الجوال"
            value={phone}
            onChangeText={setPhone}
            keyboardType="phone-pad"
            textAlign="left"
            placeholder="+967 7XX XXX XXX"
          />

          <View style={{ gap: space.xs }}>
            <Text style={[text.small, { textAlign: 'right', color: colors.ink2 }]}>المحافظة</Text>
            {governorates.error ? (
              <Empty title="تعذّر تحميل المحافظات" description={governorates.error} />
            ) : (
              <View style={styles.chips}>
                {(governorates.data ?? []).map((item) => {
                  const active = governorate === item.name
                  return (
                    <Pressable
                      key={item.id}
                      onPress={() => setGovernorate(item.name)}
                      style={[styles.chip, active && styles.chipActive]}
                    >
                      <Text style={[styles.chipText, active && styles.chipTextActive]}>
                        {item.name}
                      </Text>
                    </Pressable>
                  )
                })}
              </View>
            )}
          </View>

          {error ? (
            <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>{error}</Text>
          ) : null}

          <Button label="متابعة" onPress={submit} busy={busy} />
        </Card>

        <Button label="تسجيل الخروج" variant="ghost" onPress={() => void signOut()} />
      </ScrollView>
    </Screen>
  )
}

const styles = {
  chips: { flexDirection: 'row-reverse' as const, flexWrap: 'wrap' as const, gap: space.sm },
  chip: {
    borderWidth: 1,
    borderColor: colors.hairline,
    backgroundColor: colors.surface,
    borderRadius: radius.pill,
    paddingHorizontal: space.md,
    paddingVertical: space.sm,
  },
  chipActive: { borderColor: colors.accent, backgroundColor: colors.accent },
  chipText: { fontSize: 13, color: colors.ink2 },
  chipTextActive: { color: colors.accentInk, fontWeight: '600' as const },
}
