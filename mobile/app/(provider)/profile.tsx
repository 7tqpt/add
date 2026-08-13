import { useCallback } from 'react'
import { ScrollView, Text, View } from 'react-native'
import { useRouter } from 'expo-router'
import { Badge, Body, Button, Card, ErrorNote, Heading, Loading, Row, Screen } from '@/ui/kit'
import { requireSupabase } from '@/lib/supabase'
import { useSession } from '@/lib/session'
import { useAsync } from '@/lib/useAsync'
import { formatMoney } from '@/lib/format'
import { colors, space, text } from '@/lib/theme'
import type { ProviderProfile } from '@/lib/types'

const STATUS_LABEL = {
  pending: 'قيد المراجعة',
  verified: 'موثّق',
  rejected: 'مرفوض',
  suspended: 'موقوف',
} as const

const STATUS_TONE = {
  pending: 'warning',
  verified: 'good',
  rejected: 'critical',
  suspended: 'critical',
} as const

export default function Profile() {
  const { providerId, setRole, signOut } = useSession()
  const router = useRouter()

  const load = useCallback(async (): Promise<ProviderProfile | null> => {
    if (!providerId) return null
    const { data, error } = await requireSupabase()
      .from('service_providers')
      .select(
        'id, full_name, business_name, phone, bio, governorate, status, rating, reviews_count, completed_bookings, total_earnings, rejection_reason',
      )
      .eq('id', providerId)
      .maybeSingle()
    if (error) throw error
    return (data as ProviderProfile | null) ?? null
  }, [providerId])
  const profile = useAsync(load, [providerId])

  if (profile.loading) return <Screen><Loading /></Screen>
  if (profile.error) return <Screen><ErrorNote message={profile.error} onRetry={profile.reload} /></Screen>

  const record = profile.data

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ padding: space.lg, gap: space.md }}>
        {record ? (
          <>
            <Card>
              <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
                <Heading>{record.business_name || record.full_name}</Heading>
                <Badge label={STATUS_LABEL[record.status]} tone={STATUS_TONE[record.status]} />
              </View>
              <Text style={[text.small, { textAlign: 'right' }]}>{record.governorate}</Text>
              {record.bio ? <Body>{record.bio}</Body> : null}

              {record.status === 'pending' ? (
                <Text style={[text.small, { textAlign: 'right', color: colors.warning }]}>
                  طلبك قيد المراجعة. لن تستقبل حجوزات حتى تُقبل مستنداتك.
                </Text>
              ) : null}
              {record.status === 'rejected' && record.rejection_reason ? (
                <Text style={[text.small, { textAlign: 'right', color: colors.critical }]}>
                  {record.rejection_reason}
                </Text>
              ) : null}
            </Card>

            <Card>
              <Heading>أرقامك</Heading>
              <Row label="التقييم" value={record.rating > 0 ? `★ ${record.rating}` : 'لا تقييم بعد'} />
              <Row label="عدد التقييمات" value={String(record.reviews_count)} />
              <Row label="حجوزات منفّذة" value={String(record.completed_bookings)} />
              <Row label="إجمالي الأرباح" value={formatMoney(record.total_earnings)} />
            </Card>
          </>
        ) : (
          <Card>
            <Heading>لا ملف مقدّم خدمة</Heading>
            <Body>لم تُقدّم طلباً بعد.</Body>
          </Card>
        )}

        <Card>
          <Heading>الدعم</Heading>
          <Body>مشكلة في المستندات أو الحجوزات؟ افتح تذكرة وتصلك ردود الإدارة.</Body>
          <Button label="تذاكر الدعم" variant="secondary" onPress={() => router.push('/support')} />
        </Card>

        <Button
          label="العودة إلى وضع العميل"
          variant="secondary"
          onPress={() => {
            setRole('customer')
            router.replace('/(customer)/explore')
          }}
        />
        <Button label="تسجيل الخروج" variant="ghost" onPress={() => void signOut()} />
      </ScrollView>
    </Screen>
  )
}
