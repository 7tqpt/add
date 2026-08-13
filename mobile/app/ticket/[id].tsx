import { useCallback, useState } from 'react'
import { FlatList, Text, View } from 'react-native'
import { Stack, useLocalSearchParams } from 'expo-router'
import { Button, Card, ErrorNote, Input, Loading, Screen } from '@/ui/kit'
import { listTicketMessages, replyTicket } from '@/lib/api'
import { useAsync, messageOf } from '@/lib/useAsync'
import { formatDateTime } from '@/lib/format'
import { colors, radius, space, text } from '@/lib/theme'

const AUTHOR_LABEL = { customer: 'أنت', provider: 'أنت', admin: 'الإدارة' } as const

export default function Ticket() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const load = useCallback(() => listTicketMessages(id), [id])
  const messages = useAsync(load, [id])
  const [reply, setReply] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function send() {
    if (!reply.trim()) return
    setBusy(true)
    setError(null)
    try {
      await replyTicket(id, reply.trim())
      setReply('')
      messages.reload()
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'التذكرة' }} />
      {messages.loading ? (
        <Loading />
      ) : messages.error ? (
        <ErrorNote message={messages.error} onRetry={messages.reload} />
      ) : (
        <FlatList
          data={messages.data ?? []}
          keyExtractor={(item) => item.id}
          contentContainerStyle={{ padding: space.lg, gap: space.md }}
          renderItem={({ item }) => {
            const mine = item.author !== 'admin'
            return (
              <View style={[styles.bubble, mine ? styles.mine : styles.theirs]}>
                <Text style={[text.tiny, { textAlign: 'right' }]}>
                  {AUTHOR_LABEL[item.author]} · {formatDateTime(item.created_at)}
                </Text>
                <Text style={[text.body, { textAlign: 'right', color: colors.ink }]}>{item.body}</Text>
              </View>
            )
          }}
        />
      )}

      <View style={{ padding: space.lg, gap: space.sm, borderTopWidth: 1, borderTopColor: colors.hairline }}>
        <Input label="ردّك" value={reply} onChangeText={setReply} multiline placeholder="اكتب ردّك…" />
        {error ? (
          <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>{error}</Text>
        ) : null}
        <Button label="إرسال" onPress={send} busy={busy} disabled={!reply.trim()} />
      </View>
    </Screen>
  )
}

const styles = {
  bubble: {
    borderRadius: radius.md,
    padding: space.md,
    gap: space.xs,
    maxWidth: '86%' as const,
    borderWidth: 1,
  },
  // رسائل الإدارة على اليسار ورسائلك على اليمين — كترتيب المحادثة في الواتساب
  // العربي، فيُعرف صاحب الكلام بلا قراءة الاسم.
  mine: { alignSelf: 'flex-end' as const, backgroundColor: colors.surface, borderColor: colors.hairline },
  theirs: { alignSelf: 'flex-start' as const, backgroundColor: colors.surface2, borderColor: colors.surface2 },
}
