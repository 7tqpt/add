import { useCallback, useState } from 'react'
import { Pressable, ScrollView, Text, View } from 'react-native'
import { Stack, useRouter } from 'expo-router'
import { Body, Button, Card, Heading, Input, Loading, Screen } from '@/ui/kit'
import { applyAsProvider, listCategories, listGovernorates } from '@/lib/api'
import { useSession } from '@/lib/session'
import { useAsync, messageOf } from '@/lib/useAsync'
import { colors, radius, space, text } from '@/lib/theme'

export default function BecomeProvider() {
  const router = useRouter()
  const { refresh } = useSession()

  const loadRefs = useCallback(
    async () => ({
      categories: await listCategories(),
      governorates: await listGovernorates(),
    }),
    [],
  )
  const refs = useAsync(loadRefs, [])

  const [businessName, setBusinessName] = useState('')
  const [phone, setPhone] = useState('')
  const [bio, setBio] = useState('')
  const [governorate, setGovernorate] = useState<string | null>(null)
  const [picked, setPicked] = useState<string[]>([])
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  function toggle(id: string) {
    setPicked((current) =>
      current.includes(id) ? current.filter((x) => x !== id) : [...current, id],
    )
  }

  async function submit() {
    if (!businessName.trim() || !phone.trim() || !governorate || picked.length === 0) {
      setError('اكتب اسم المنشأة ورقمك، واختر محافظتك وقسماً واحداً على الأقل.')
      return
    }
    setError(null)
    setBusy(true)
    try {
      await applyAsProvider({
        businessName: businessName.trim(),
        phone: phone.trim(),
        bio: bio.trim(),
        governorate,
        categoryIds: picked,
      })
      refresh()
      router.replace('/(provider)/profile')
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  if (refs.loading) {
    return (
      <Screen>
        <Stack.Screen options={{ title: 'تقديم خدمة' }} />
        <Loading />
      </Screen>
    )
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'تقديم خدمة' }} />
      <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.md }}>
        <Card>
          <Heading>سجّل منشأتك</Heading>
          <Body>
            بعد الإرسال يصير ملفك «قيد المراجعة». ترفع مستنداتك، وحين تقبلها الإدارة تبدأ
            باستقبال الحجوزات.
          </Body>

          <Input
            label="اسم المنشأة"
            value={businessName}
            onChangeText={setBusinessName}
            placeholder="قاعة التاج"
          />
          <Input
            label="رقم التواصل"
            value={phone}
            onChangeText={setPhone}
            keyboardType="phone-pad"
            textAlign="left"
            placeholder="+967 7XX XXX XXX"
          />
          <Input
            label="نبذة"
            value={bio}
            onChangeText={setBio}
            multiline
            placeholder="ماذا تقدّم؟ وما الذي يميّزك؟"
          />

          <View style={{ gap: space.xs }}>
            <Text style={[text.small, { textAlign: 'right', color: colors.ink2 }]}>المحافظة</Text>
            <View style={styles.chips}>
              {(refs.data?.governorates ?? []).map((item) => {
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
          </View>

          <View style={{ gap: space.xs }}>
            <Text style={[text.small, { textAlign: 'right', color: colors.ink2 }]}>
              الأقسام التي تعمل فيها
            </Text>
            <View style={styles.chips}>
              {(refs.data?.categories ?? []).map((item) => {
                const active = picked.includes(item.id)
                return (
                  <Pressable
                    key={item.id}
                    onPress={() => toggle(item.id)}
                    style={[styles.chip, active && styles.chipActive]}
                  >
                    <Text style={[styles.chipText, active && styles.chipTextActive]}>
                      {item.name}
                    </Text>
                  </Pressable>
                )
              })}
            </View>
          </View>

          {error ? (
            <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>{error}</Text>
          ) : null}

          <Button label="إرسال الطلب" onPress={submit} busy={busy} />
        </Card>
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
