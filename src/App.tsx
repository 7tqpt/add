import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AppLayout } from '@/components/layout/AppLayout'
import { LoadingBlock } from '@/components/ui/Feedback'
import { useAuth } from '@/context/AuthContext'
import { DashboardPage } from '@/pages/Dashboard'
import { LoginPage } from '@/pages/Login'
import { NotFoundPage } from '@/pages/NotFound'
import { NotificationsPage } from '@/pages/Notifications'
import { SettingsPage } from '@/pages/Settings'
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
        <Route path="/users" element={<UsersPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="/versions" element={<VersionsPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
