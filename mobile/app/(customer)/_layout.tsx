import { Tabs } from 'expo-router'
import { Ionicons } from '@expo/vector-icons'
import { colors } from '@/lib/theme'
import { TabLabel } from '@/ui/TabLabel'

export default function CustomerTabs() {
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
        name="explore"
        options={{
          title: 'استكشف',
          tabBarLabel: ({ color }) => <TabLabel label="استكشف" color={color} />,
          tabBarIcon: ({ color, size }) => <Ionicons name="search" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="bookings"
        options={{
          title: 'حجوزاتي',
          tabBarLabel: ({ color }) => <TabLabel label="حجوزاتي" color={color} />,
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="calendar-outline" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen
        name="plan"
        options={{
          title: 'خطتي',
          tabBarLabel: ({ color }) => <TabLabel label="خطتي" color={color} />,
          tabBarIcon: ({ color, size }) => <Ionicons name="heart-outline" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="account"
        options={{
          title: 'حسابي',
          tabBarLabel: ({ color }) => <TabLabel label="حسابي" color={color} />,
          tabBarIcon: ({ color, size }) => <Ionicons name="person-outline" size={size} color={color} />,
        }}
      />
    </Tabs>
  )
}
