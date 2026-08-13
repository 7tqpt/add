import { useCallback, useMemo, useState } from 'react'
import { Alert, Platform, ScrollView, Text, View } from 'react-native'
import { Stack, useLocalSearchParams, useRouter } from 'expo-router'
import { Badge, Body, Button, Card, ErrorNote, Heading, Input, Loading, Row, Screen } from '@/ui/kit'
import { createBooking, getService } from '@/lib/api'
import { useAsync, messageOf } from '@/lib/useAsync'
import { formatMoney } from '@/lib/format'
import { colors, space, text } from '@/lib/theme'

/** YYYY-MM-DD — نفس ما تتوقّعه `api_create_booking`. */
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/
const HH_MM = /^\d{2}:\d{2}$/

export default function ServiceDetail() {
  const { id } = useLocalSearchParams<{ id: string }>()
  const router = useRouter()
  const load = useCallback(() => getService(id), [id])
  const service = useAsync(load, [id])

  const [date, setDate] = useState('')
  const [time, setTime] = useState('20:00')
  const [guests, setGuests] = useState('300')
  const [address, setAddress] = useState('')
  const [notes, setNotes] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const record = service.data
  const deposit = useMemo(
    () => (record ? Math.round((record.price * record.deposit_percent) / 100) : 0),
    [record],
  )

  async function book() {
    if (!record) return
    if (!ISO_DATE.test(date)) {
      setError('اكتب تاريخ العرس بصيغة سنة-شهر-يوم، مثل 2026-09-15.')
      return
    }
    if (time && !HH_MM.test(time)) {
      setError('اكتب الوقت بصيغة ساعة:دقيقة، مثل 20:00.')
      return
    }
    const count = Number(guests)
    if (!Number.isFinite(count) || count <= 0) {
      setError('اكتب عدد الضيوف رقماً.')
      return
    }
    if (!address.trim()) {
      setError('اكتب عنوان المناسبة.')
      return
    }

    setError(null)
    setBusy(true)
    try {
      const booking = await createBooking({
        serviceId: record.id,
        eventDate: date,
        eventTime: time || null,
        guests: count,
        address: address.trim(),
        notes: notes.trim(),
      })
      const message = `رقم حجزك ${booking.reference}. العربون ${formatMoney(booking.deposit_amount)} — يبقى الحجز معلّقاً حتى يردّ مقدّم الخدمة.`
      if (Platform.OS === 'web') {
        // Alert.alert لا يعرض شيئاً على الويب، فيبدو الحجز وكأنه لم يقع.
        // eslint-disable-next-line no-alert
        window.alert(message)
      } else {
        Alert.alert('تم إنشاء الحجز', message)
      }
      router.replace('/(customer)/bookings')
    } catch (cause) {
      setError(messageOf(cause))
    } finally {
      setBusy(false)
    }
  }

  if (service.loading) {
    return (
      <Screen>
        <Stack.Screen options={{ title: 'الخدمة' }} />
        <Loading />
      </Screen>
    )
  }
  if (service.error || !record) {
    return (
      <Screen>
        <Stack.Screen options={{ title: 'الخدمة' }} />
        <ErrorNote message={service.error ?? 'الخدمة غير موجودة.'} onRetry={service.reload} />
      </Screen>
    )
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: record.category_name }} />
      <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.md }}>
        <Card>
          <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
            <Heading>{record.title}</Heading>
            {record.provider_is_featured ? <Badge label="مميّز" tone="warning" /> : null}
          </View>
          <Text style={[text.small, { textAlign: 'right' }]}>
            {record.provider_name} · {record.provider_governorate}
            {record.provider_rating > 0
              ? ` · ★ ${record.provider_rating} (${record.provider_reviews_count})`
              : ''}
          </Text>
          {record.description ? <Body>{record.description}</Body> : null}
        </Card>

        <Card>
          <Heading>السعر</Heading>
          <Row
            label="السعر"
            value={
              record.price_to
                ? `${formatMoney(record.price)} – ${formatMoney(record.price_to)}`
                : formatMoney(record.price)
            }
          />
          <Row label="الوحدة" value={record.unit} />
          <Row label={`العربون ${record.deposit_percent}٪`} value={formatMoney(deposit)} />
          {record.cancellation_policy_name ? (
            <Row label="سياسة الإلغاء" value={record.cancellation_policy_name} />
          ) : null}
          {/*
            السعر المعروض للاطّلاع، والمعتمد ما يحسبه الخادم عند الحجز: لو قبِل
            سعراً من التطبيق لأمكن حجز قاعة بريال واحد.
          */}
          <Text style={[text.tiny, { textAlign: 'right' }]}>
            المبلغ النهائي يحسبه النظام عند تأكيد الحجز.
          </Text>
        </Card>

        <Card>
          <Heading>احجز</Heading>
          <Input
            label="تاريخ العرس"
            value={date}
            onChangeText={setDate}
            placeholder="2026-09-15"
            textAlign="left"
            keyboardType="numbers-and-punctuation"
          />
          <Input
            label="الوقت"
            value={time}
            onChangeText={setTime}
            placeholder="20:00"
            textAlign="left"
            keyboardType="numbers-and-punctuation"
          />
          <Input
            label="عدد الضيوف"
            value={guests}
            onChangeText={setGuests}
            keyboardType="number-pad"
            textAlign="left"
          />
          <Input
            label="عنوان المناسبة"
            value={address}
            onChangeText={setAddress}
            placeholder="حي السنينة — صنعاء"
          />
          <Input
            label="ملاحظات (اختياري)"
            value={notes}
            onChangeText={setNotes}
            multiline
            placeholder="أي تفاصيل يحتاجها مقدّم الخدمة"
          />

          {error ? (
            <Text style={[text.small, { color: colors.critical, textAlign: 'right' }]}>{error}</Text>
          ) : null}

          <Button label="تأكيد الحجز" onPress={book} busy={busy} />
          <Text style={[text.tiny, { textAlign: 'right' }]}>
            الحجز يبقى «بانتظار مقدّم الخدمة» حتى يقبله. لو اعتذر، يُستردّ كل ما دفعته.
          </Text>
        </Card>
      </ScrollView>
    </Screen>
  )
}
