import { Text, type ColorValue } from 'react-native'

/**
 * عنوان التبويب بنصّه لا بنصّ react-navigation.
 *
 * العنوان الافتراضي يُحصر في صندوق ارتفاعه تسع نقاط، وهو يكفي الحروف اللاتينية
 * ولا يكفي العربية: «ج» و«ي» تنزلان تحت السطر فتُقصّان، فتُقرأ «حجوزاتي» ناقصة.
 * تمرير عنصر Text خاص يتجاوز ذلك القياس.
 */
export function TabLabel({ label, color }: { label: string; color: ColorValue }) {
  return (
    <Text
      numberOfLines={1}
      style={{ fontSize: 11, lineHeight: 16, color, textAlign: 'center', includeFontPadding: false }}
    >
      {label}
    </Text>
  )
}
