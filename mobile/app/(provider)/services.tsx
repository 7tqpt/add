import { useCallback } from 'react'
import { FlatList, RefreshControl, Text, View } from 'react-native'
import { Badge, Card, Empty, ErrorNote, Loading, Screen } from '@/ui/kit'
import { requireSupabase } from '@/lib/supabase'
import { useSession } from '@/lib/session'
import { useAsync } from '@/lib/useAsync'
import { formatMoney } from '@/lib/format'
import { colors, space, text } from '@/lib/theme'

interface MyService {
  id: string
  title: string
  price: number
  price_to: number | null
  unit: string
  deposit_percent: number
  is_active: boolean
  category_id: string
}

export default function Services() {
  const { providerId } = useSession()
  const load = useCallback(async (): Promise<MyService[]> => {
    if (!providerId) return []
    const { data, error } = await requireSupabase()
      .from('provider_services')
      .select('id, title, price, price_to, unit, deposit_percent, is_active, category_id')
      .eq('provider_id', providerId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return (data ?? []) as MyService[]
  }, [providerId])
  const services = useAsync(load, [providerId])

  if (services.loading) return <Screen><Loading /></Screen>
  if (services.error) return <Screen><ErrorNote message={services.error} onRetry={services.reload} /></Screen>

  const rows = services.data ?? []
  if (rows.length === 0) {
    return (
      <Screen>
        <Empty
          title="لا خدمات منشورة"
          description="تُضاف الخدمات وتُسعَّر من لوحة التحكم حالياً. سنُتيح إضافتها من هنا قريباً."
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
          <RefreshControl refreshing={false} onRefresh={services.reload} tintColor={colors.accent} />
        }
        renderItem={({ item }) => (
          <Card>
            <View style={{ flexDirection: 'row-reverse', justifyContent: 'space-between', gap: space.sm }}>
              <Text style={[text.heading, { flex: 1, textAlign: 'right' }]} numberOfLines={2}>
                {item.title}
              </Text>
              <Badge
                label={item.is_active ? 'معروضة' : 'مخفيّة'}
                tone={item.is_active ? 'good' : 'neutral'}
              />
            </View>
            <Text style={[text.body, { textAlign: 'right', color: colors.accent }]}>
              {formatMoney(item.price)}
              {item.price_to ? ` – ${formatMoney(item.price_to)}` : ''} · {item.unit}
            </Text>
            <Text style={[text.tiny, { textAlign: 'right' }]}>العربون {item.deposit_percent}٪</Text>
          </Card>
        )}
      />
    </Screen>
  )
}
