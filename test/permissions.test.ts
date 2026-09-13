// صلاحياتُ المسؤولين في اللوحة — `src/lib/permissions.ts`.
//
// ── وما لا يقيسه هذا الملفّ ──────────────────────────────────────────────────
//
// **مطابقةُ المصفوفة لأصلها في `roles.sql` مقيسةٌ في مكانٍ آخر**:
// `supabase/tests/permissions.sync.test.mjs` يبني قاعدةً حقيقيّةً ويقارن
// الجدولَ بالملفّ خانةً بخانة. فلا يُكرَّر هنا.
//
// **وهذه ليست الحماية أصلاً.** الحمايةُ سياساتُ RLS في القاعدة، وهي وحدَها
// ما يمنع طلباً يُرسَل من خارج اللوحة. وما هنا يقرّر **ماذا يُعرض** — وزرٌّ
// يُعرض لمن لا يملكه يُضغط فيرتدّ عليه الطلبُ بخطأٍ لا يفهمه.
//
// ── فما يُقاس هنا ما حول المصفوفة ────────────────────────────────────────────
//
// الدوالُّ الثلاثُ التي تقرؤها، وحالُ من لا دورَ له، وأنّ القوائمَ المعروضة
// لا تُسقط دوراً ولا مجالاً — فمجالٌ يسقط من `AREAS_IN_ORDER` يختفي من شاشة
// الصلاحيّات كلَّها وهو قائمٌ في القاعدة.
import { describe, expect, it } from 'vitest'

import {
  AREAS_IN_ORDER,
  AREA_LABEL,
  LEVEL_LABEL,
  ROLES_IN_ORDER,
  ROLE_AREAS,
  ROLE_DESCRIPTION,
  ROLE_LABEL,
  canRead,
  canWriteArea,
  levelOf,
} from '../src/lib/permissions'

describe('من لا دورَ له', () => {
  it('**ولا يقرأ ولا يكتب شيئاً**', () => {
    // `null` هي حالُ من لم تصل جلستُه بعد، أو من نُزع دورُه وهو مفتوحُ
    // اللوحة. **والافتراضُ منعٌ لا سماح.**
    for (const area of AREAS_IN_ORDER) {
      expect(levelOf(null, area)).toBe('none')
      expect(canRead(null, area)).toBe(false)
      expect(canWriteArea(null, area)).toBe(false)
    }
  })

  it('**ودورٌ لا نعرفه يُقرأ منعاً لا خطأً**', () => {
    // القاعدةُ قد تحمل دوراً أحدثَ من اللوحة — فلوحةٌ قديمةٌ أمام قاعدةٍ
    // أحدثَ يجب أن **تُخفي** لا أن تسقط ولا أن تفتح.
    const unknown = 'superuser' as never
    expect(levelOf(unknown, 'finance')).toBe('none')
    expect(canRead(unknown, 'finance')).toBe(false)
  })
})

describe('قراءةُ المستويات', () => {
  it('**و«تعديل» يعني قراءةً كذلك**', () => {
    // ولولا هذا لَرأى المالكُ زرَّ التعديل ولم يرَ ما يُعدّله.
    expect(canRead('owner', 'admins')).toBe(true)
    expect(canWriteArea('owner', 'admins')).toBe(true)
  })

  it('و«قراءة» ليست تعديلاً', () => {
    expect(canRead('viewer', 'bookings')).toBe(true)
    expect(canWriteArea('viewer', 'bookings')).toBe(false)
  })
})

describe('حدودُ الأدوار كما وُصفت لأصحابها', () => {
  // **والوصفُ عهدٌ لا زينة:** مكتوبٌ في `ROLE_DESCRIPTION` ويُعرض لمن
  // يُسنَد إليه الدور. فما قيل فيه يُقاس هنا.

  it('**والمالكُ وحدَه يُدير المسؤولين**', () => {
    // «هو وحده يضيف المسؤولين ويغيّر أدوارهم».
    const writers = ROLES_IN_ORDER.filter((r) => canWriteArea(r, 'admins'))
    expect(writers).toEqual(['owner'])
    // ولا يراهم غيرُه أصلاً.
    const readers = ROLES_IN_ORDER.filter((r) => canRead(r, 'admins'))
    expect(readers).toEqual(['owner'])
  })

  it('**والمالُ محجوبٌ عن خدمة العملاء والمشرف والمطّلع**', () => {
    // «لا يرى المال» — ثلاث مرّاتٍ في الأوصاف.
    for (const role of ['support', 'moderator', 'viewer'] as const) {
      expect(levelOf(role, 'finance')).toBe('none')
    }
  })

  it('**والمحاسبُ لا يوثّق أحداً ولا يغيّر الأقسام**', () => {
    expect(canWriteArea('finance', 'finance')).toBe(true)
    expect(canWriteArea('finance', 'directory')).toBe(false)
    expect(levelOf('finance', 'catalog')).toBe('none')
  })

  it('**والمديرُ له كلُّ شيءٍ عدا المسؤولين**', () => {
    for (const area of AREAS_IN_ORDER) {
      expect(levelOf('manager', area)).toBe(area === 'admins' ? 'none' : 'write')
    }
  })

  it('**والمطّلعُ لا يكتب في موضعٍ واحد**', () => {
    const written = AREAS_IN_ORDER.filter((a) => canWriteArea('viewer', a))
    expect(written).toEqual([])
  })
})

describe('القوائمُ المعروضة', () => {
  it('**ولا يسقط دورٌ ولا مجالٌ من الترتيب**', () => {
    // شاشةُ الصلاحيّات تُبنى من هاتين القائمتين. فمجالٌ يسقط منهما يختفي
    // من الشاشة كلِّها وهو قائمٌ في القاعدة — ولا رسالةَ خطأٍ تقول ذلك.
    expect([...ROLES_IN_ORDER].sort()).toEqual(Object.keys(ROLE_AREAS).sort())
    expect([...AREAS_IN_ORDER].sort()).toEqual(Object.keys(ROLE_AREAS.owner).sort())
  })

  it('**ولكلّ دورٍ اسمٌ ووصفٌ بالعربيّة**', () => {
    // دورٌ بلا اسمٍ يُعرض مفتاحاً إنجليزيّاً في قائمةٍ عربيّة.
    for (const role of ROLES_IN_ORDER) {
      expect(ROLE_LABEL[role]?.trim()).toBeTruthy()
      expect(ROLE_DESCRIPTION[role]?.trim()).toBeTruthy()
    }
  })

  it('ولكلّ مجالٍ ومستوىً اسم', () => {
    for (const area of AREAS_IN_ORDER) expect(AREA_LABEL[area]?.trim()).toBeTruthy()
    for (const level of ['none', 'read', 'write'] as const) {
      expect(LEVEL_LABEL[level]?.trim()).toBeTruthy()
    }
  })

  // **وكان هنا اختبارٌ على ترتيب الأدوار فحُذف — ولا يُعاد.**
  //
  // في الملفّ سطرٌ يقول «الأدوار مرتّبةً من الأوسع صلاحيةً إلى الأضيق»،
  // فكتبتُ مقياساً يجمع المستويات عدداً (‏`none`=0, `read`=1, `write`=2‏)
  // ويتأكّد أنّ المجموع ينزل. **فسقط**: المطّلعُ يقرأ سبعةَ مجالاتٍ فمجموعُه
  // ‎٧‎، والمحاسبُ يكتب المالَ ويقرأ ثلاثةً فمجموعُه ‎٥‎.
  //
  // **والعطبُ في المقياس لا في الترتيب.** «الأوسع» سلطةٌ لا عددُ خانات —
  // ومن يُحرّك أموالَ المنصّة أوسعُ ممّن يقرأ سبعَ شاشاتٍ ولا يمسّ شيئاً.
  // فحُذف، ولم يُترك حرزٌ يقيس معياراً اخترعتُه أنا.
})
