@@
 import { useState } from 'react'
-import { Database } from 'lucide-react'
+import { Database } from 'lucide-react'
 import { isSupabaseConfigured } from '@/lib/supabase'
 import { Sidebar } from './Sidebar'
 import { Topbar } from './Topbar'
 import { titleForPath } from './nav'
+import { Icon } from '@/components/ui/Icon'
@@
-          <Database size={14} aria-hidden className="shrink-0 text-muted" />
+            <Icon icon={Database} size={14} className="shrink-0 text-muted" />
