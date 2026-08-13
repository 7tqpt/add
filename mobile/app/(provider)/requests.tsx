import { useCallback, useState } from 'react'
import { Alert, FlatList, Platform, RefreshControl, Text, View } from 'react-native'
import { Badge, Button, Card, Empty, ErrorNote, Loading, Screen } from '@/ui/kit'
import { completeBooking, listMyBookings, respondToBooking } from '@/lib/api'
import { useAsync, messageOf } from '@/lib/useAsync'
import { formatDate, formatMoney, formatTime } from '@/lib/format'
import { BOOKING_STATUS_LABEL, BOOKING_STATUS_TONE } from '@/lib/labels'
import { colors, space, text } from '@/lib/theme'

function notify(title: string, message: string) {
  if (Platform.OS === 'web') window.alert(`${title}\n\n${message}`)
  else Alert.alert(title, message)
}

export default function Requests() {
  const load = useCallback(() => listMyBookings(), [])
  const bookings = useAsync(load, [])
  const [busyId, setBusyId] = useState<string | null>(null)

  async function respond(id: string, accept: boolean) {
    setBusyId(id)
    try {
      await respondToBooking(id, accept, accept ? '' : 'غير متاح في هذا الموعد')
      notify(
        accept ? 'قُبل الحجز' : 'رُفض الحجز',
        accept ? 'أُغلق اليوم في تقويمك ووصل العميل إشعار.' : 'أُعيد للعميل كل ما دفعه.',
      )
      bookings.reload()
    } catch (cause) {
      notify('تعذّر التنفيذ', messageOf(cause))
    } finally {
      setBusyId(null)
    }
  }

  async function complete(id: string) {
    setBusyId(id)
    try {
      await completeBooking(id)
      notify('تم التأكيد', 'سُجّل تنفيذ الحجز، وفُتح للعميل باب التقييم.')
      bookings.reload()
    } catch (cause) {
      notify('تعذّر التنفيذ', messageOf(cause))
    } finally {
      setBusyId(null)
    }
  }

  if (bookings.loading) return <Screen><Loading /></Screen>
  if (bookings.error) return <Screen><ErrorNote message={bookings.error} onRetry={bookings.reload} /></Screen>

  const rows = bookings.data ?? []
  if (rows.length === 0) {
    return (
      <Screen>
        <Empty
          title="لا طلبات بعد"
          description="ستصلك هنا حجوزات العملاء على خدماتك."
        />
      </Screen>
    )
  }

  return (
    <Screen>
      <FlatList
        data={rows}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ padding: space.lg, gap: space.md }}
        refreshControl={
          <RefreshControl refreshing={false} onRefresh={bookings.reload} tintColor={colors.accent} />
        }
        renderItem={({ item }) => (
          <Card>
            <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
              <Text style={[text.heading, { flex: 1, textAlign: 'right' }]} numberOfLines={2}>
                {item.service_title}
              </Text>
              <Badge label={BOOKING_STATUS_LABEL[item.status]} tone={BOOKING_STATUS_TONE[item.status]} />
            </View>

            <Text style={[text.small, { textAlign: 'right' }]}>
              {item.user_name} · {item.guests_count} ضيف
            </Text>
            <Text style={[text.body, { textAlign: 'right' }]}>
              {formatDate(item.event_date)}
              {item.event_time ? ` · ${formatTime(item.event_time)}` : ''}
            </Text>
            <Text style={[text.small, { textAlign: 'right' }]}>{item.address}</Text>
            <Text style={[text.small, { textAlign: 'right', color: colors.ink }]}>
              {formatMoney(item.total_price)}
            </Text>

            {item.status === 'pending_provider' ? (
              <View style={{ flexDirection: 'row-reverse', gap: space.sm, marginTop: space.sm }}>
                <View style={{ flex: 1 }}>
                  <Button label="قبول" onPress={() => respond(item.id, true)} busy={busyId === item.id} />
                </View>
                <View style={{ flex: 1 }}>
                  <Button
                    label="اعتذار"
                    variant="secondary"
                    onPress={() => respond(item.id, false)}
                    disabled={busyId === item.id}
                  />
                </View>
              </View>
            ) : null}

            {item.status === 'confirmed' ? (
              <View style={{ marginTop: space.sm }}>
                <Button
                  label="تأكيد التنفيذ"
                  variant="secondary"
                  onPress={() => complete(item.id)}
                  busy={busyId === item.id}
                />
              </View>
            ) : null}
          </Card>
        )}
      />
    </Screen>
  )
}
