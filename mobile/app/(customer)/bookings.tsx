import { useCallback } from 'react'
import { FlatList, RefreshControl, Text, View } from 'react-native'
import { Badge, Card, Empty, ErrorNote, Loading, Screen } from '@/ui/kit'
import { listMyBookings } from '@/lib/api'
import { useAsync } from '@/lib/useAsync'
import { formatDate, formatMoney, formatTime } from '@/lib/format'
import { BOOKING_STATUS_LABEL, BOOKING_STATUS_TONE } from '@/lib/labels'
import { colors, space, text } from '@/lib/theme'

export default function MyBookings() {
  const load = useCallback(() => listMyBookings(), [])
  const bookings = useAsync(load, [])

  if (bookings.loading) {
    return (
      <Screen>
        <Loading />
      </Screen>
    )
  }
  if (bookings.error) {
    return (
      <Screen>
        <ErrorNote message={bookings.error} onRetry={bookings.reload} />
      </Screen>
    )
  }

  const rows = bookings.data ?? []
  if (rows.length === 0) {
    return (
      <Screen>
        <Empty
          title="لا حجوزات بعد"
          description="ابدأ من «استكشف» واختر أول خدمة لعرسك."
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

            <Text style={[text.small, { textAlign: 'right' }]}>{item.provider_name}</Text>

            <Text style={[text.body, { textAlign: 'right' }]}>
              {formatDate(item.event_date)}
              {item.event_time ? ` · ${formatTime(item.event_time)}` : ''}
            </Text>

            <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between' }}>
              <Text style={[text.small, { color: colors.ink }]}>
                الإجمالي {formatMoney(item.total_price)}
              </Text>
              <Text style={text.tiny}>
                {item.paid_amount > 0 ? `مدفوع ${formatMoney(item.paid_amount)}` : 'لم يُدفع بعد'}
              </Text>
            </View>

            <Text style={[text.tiny, { textAlign: 'left' }]}>{item.reference}</Text>
          </Card>
        )}
      />
    </Screen>
  )
}
