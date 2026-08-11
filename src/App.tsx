import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AppLayout } from '@/components/layout/AppLayout'
import { LoadingBlock } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { AuditPage } from '@/pages/Audit'
import { BookingDetailPage } from '@/pages/BookingDetail'
import { BookingsPage } from '@/pages/Bookings'
import { CatalogPage } from '@/pages/Catalog'
import { DashboardPage } from '@/pages/Dashboard'
import { DisputeDetailPage } from '@/pages/DisputeDetail'
import { DisputesPage } from '@/pages/Disputes'
import { LoginPage } from '@/pages/Login'
import { NotFoundPage } from '@/pages/NotFound'
import { NotificationsPage } from '@/pages/Notifications'
import { PaymentsPage } from '@/pages/Payments'
import { PlanDetailPage } from '@/pages/PlanDetail'
import { PlansPage } from '@/pages/Plans'
import { PromotionsPage } from '@/pages/Promotions'
import { ProviderDetailPage } from '@/pages/ProviderDetail'
import { ProvidersPage } from '@/pages/Providers'
import { ReviewsPage } from '@/pages/Reviews'
import { SettingsPage } from '@/pages/Settings'
import { SettlementsPage } from '@/pages/Settlements'
import { UserDetailPage } from '@/pages/UserDetail'
import { UsersPage } from '@/pages/Users'
import { VersionsPage } from '@/pages/Versions'

function RequireAuth() {
  const { user, loading } = useAuth()
  const location = useLocation()

  if (loading) return <LoadingBlock label="جارٍ التحقق من الجلسة…" />
  // `state` carries the attempted URL so login can return there.
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  return <AppLayout />
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<RequireAuth />}>
        <Route path="/" element={<DashboardPage />} />

        <Route path="/bookings" element={<BookingsPage />} />
        <Route path="/bookings/:id" element={<BookingDetailPage />} />
        <Route path="/plans" element={<PlansPage />} />
        <Route path="/plans/:id" element={<PlanDetailPage />} />

        <Route path="/users" element={<UsersPage />} />
        <Route path="/users/:id" element={<UserDetailPage />} />
        <Route path="/providers" element={<ProvidersPage />} />
        <Route path="/providers/:id" element={<ProviderDetailPage />} />
        <Route path="/catalog" element={<CatalogPage />} />

        <Route path="/payments" element={<PaymentsPage />} />
        <Route path="/settlements" element={<SettlementsPage />} />
        <Route path="/promotions" element={<PromotionsPage />} />

        <Route path="/disputes" element={<DisputesPage />} />
        <Route path="/disputes/:id" element={<DisputeDetailPage />} />
        <Route path="/reviews" element={<ReviewsPage />} />

        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="/versions" element={<VersionsPage />} />
        <Route path="/audit" element={<AuditPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
