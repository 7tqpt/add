import { useCallback, useState } from 'react'
import { FlatList, Pressable, ScrollView, Text, View } from 'react-native'
import { Stack, useRouter } from 'expo-router'
import { Badge, Body, Button, Card, Empty, ErrorNote, Heading, Input, Loading, Screen } from '@/ui/kit'
import { listMyTickets, openTicket } from '@/lib/api'
import { useSession } from '@/lib/session'
import { useAsync, messageOf } from '@/lib/useAsync'
import { formatRelative } from '@/lib/format'
import { TICKET_CATEGORIES, TICKET_STATUS_LABEL } from '@/lib/labels'
import { colors, radius, space, text } from '@/lib/theme'

export default function Support() {
  const router = useRouter()
  const { role } = useSession()
  const load = useCallback(() => listMyTickets(), [])
  const tickets = useAsync(load, [])

  const [open, setOpen] = useState(false)
  const [subject, setSubject] = useState('')
  const [bodyText, setBodyText] = useState('')
  const [category, setCategory] = useState('booking')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit() {
    if (!subject.trim() || !bodyText.trim()) {
      setError('اكتب الموضوع وتفاصيل المشكلة.')
      return
    }
    setError(null)
    setBusy(true)
    try {
      await openTicket({
        subject: subject.trim(),
        body: bodyText.trim(),
        category,
        asProvider: role === 'provider',
      })
      setSubject('')
      setBodyText('')
      setOpen(false)
      tickets.reload()
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'خدمة العملاء' }} />

      {open ? (
        <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.md }}>
          <Card>
            <Heading>تذكرة جديدة</Heading>
            <Body>اشرح مشكلتك بالتفصيل، وسيصلك ردّ الإدارة هنا وبإشعار.</Body>

            <View style={{ gap: space.xs }}>
              <Text style={[text.small, { textAlign: 'right', color: colors.ink2 }]}>التصنيف</Text>
              <View style={styles.chips}>
                {TICKET_CATEGORIES.map((item) => {
                  const active = category === item.value
                  return (
                    <Pressable
                      key={item.value}
                      onPress={() => setCategory(item.value)}
                      style={[styles.chip, active && styles.chipActive]}
                    >
                      <Text style={[styles.chipText, active && styles.chipTextActive]}>
                        {item.label}
                      </Text>
                    </Pressable>
                  )
                })}
              </View>
            </View>

            <Input label="الموضوع" value={subject} onChangeText={setSubject} placeholder="خُصم المبلغ ولم يظهر الحجز" />
            <Input
              label="التفاصيل"
              value={bodyText}
              onChangeText={setBodyText}
              multiline
              placeholder="اشرح ما حدث بالتفصيل…"
              style={{ minHeight: 110, paddingTop: space.md }}
            />

            {error ? (
              <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>{error}</Text>
            ) : null}

            <Button label="إرسال" onPress={submit} busy={busy} />
            <Button label="إلغاء" variant="ghost" onPress={() => setOpen(false)} />
          </Card>
        </ScrollView>
      ) : (
        <>
          <View style={{ padding: space.lg, paddingBottom: 0 }}>
            <Button label="فتح تذكرة جديدة" onPress={() => setOpen(true)} />
          </View>

          {tickets.loading ? (
            <Loading />
          ) : tickets.error ? (
            <ErrorNote message={tickets.error} onRetry={tickets.reload} />
          ) : (tickets.data ?? []).length === 0 ? (
            <Empty title="لا تذاكر" description="لو واجهتك مشكلة، افتح تذكرة وسنردّ عليك." />
          ) : (
            <FlatList
              data={tickets.data ?? []}
              keyExtractor={(item) => item.id}
              contentContainerStyle={{ padding: space.lg, gap: space.md }}
              renderItem={({ item }) => (
                <Pressable onPress={() => router.push({ pathname: '/ticket/[id]', params: { id: item.id } })}>
                  <Card>
                    <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
                      <Text style={[text.heading, { flex: 1, textAlign: 'right' }]} numberOfLines={2}>
                        {item.subject}
                      </Text>
                      <Badge
                        label={TICKET_STATUS_LABEL[item.status]}
                        tone={
                          item.status === 'resolved'
                            ? 'good'
                            : item.status === 'waiting_customer'
                              ? 'warning'
                              : item.status === 'closed'
                                ? 'neutral'
                                : 'critical'
                        }
                      />
                    </View>
                    <Text style={[text.tiny, { textAlign: 'left' }]}>{item.reference}</Text>
                    <Text style={[text.small, { textAlign: 'right' }]}>
                      آخر حركة {formatRelative(item.last_message_at)}
                    </Text>
                  </Card>
                </Pressable>
              )}
            />
          )}
        </>
      )}
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
