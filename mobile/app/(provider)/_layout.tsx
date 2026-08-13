import { Tabs } from 'expo-router'
import { Ionicons } from '@expo/vector-icons'
import { colors } from '@/lib/theme'
import { TabLabel } from '@/ui/TabLabel'

export default function ProviderTabs() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.muted,
        // ارتفاع صريح: الافتراضي يكفي أيقونةً وكلمةً لاتينية قصيرة، أما
        // «حجوزاتي» و«خطتي» فتُقصّ من أسفل بلا هذا.
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.hairline,
          height: 64,
          paddingTop: 6,
          paddingBottom: 8,
        },
                // lineHeight صريح: حروف العربية تنزل تحت السطر («ح» و«ي» و«ج»)،
        // والارتفاع الافتراضي يقصّها من أسفل فتُقرأ «حجوزاتي» ناقصة.
        tabBarLabelStyle: { fontSize: 11, lineHeight: 17, marginTop: 2 },
        headerStyle: { backgroundColor: colors.surface },
        headerTintColor: colors.ink,
        sceneStyle: { backgroundColor: colors.page },
      }}
    >
      <Tabs.Screen
        name="requests"
        options={{
          title: 'الطلبات',
          tabBarLabel: ({ color }) => <TabLabel label="الطلبات" color={color} />,
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="notifications-outline" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="services"
        options={{
          title: 'خدماتي',
          tabBarLabel: ({ color }) => <TabLabel label="خدماتي" color={color} />,
          tabBarIcon: ({ color, size }) => <Ionicons name="pricetags-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'ملفي',
          tabBarLabel: ({ color }) => <TabLabel label="ملفي" color={color} />,
          tabBarIcon: ({ color, size }) => <Ionicons name="storefront-outline" size={size} color={color} />,
        }}
      />
    </Tabs>
  )
}
