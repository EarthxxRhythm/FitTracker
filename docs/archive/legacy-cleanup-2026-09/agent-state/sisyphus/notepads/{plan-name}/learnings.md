PlanDetailPage: migrated UI to PageHeader, Timeline width, muscle chip rendering using Chip and MuscleColorMap.
- Replaced local color mapping functions with central MuscleColorMap from DesignTokens.
- Replaced header section with PageHeader({ title, showBack }).
- Timeline column width now uses TouchTokens.TIMING_COL_WIDTH? Actually TIMELINE_COL_WIDTH as per spec.
- Replaced inline muscle badge with Chip({ label, color, chipSize: 'sm' }).
- Used ColorTokens.MUSCLE_DEFAULT for default cover color.

ProfilePage: added PageHeader and adjusted avatar to use AVATAR_SIZE and DISPLAY_SIZE for initial text.
- Avatar now uses TouchTokens.AVATAR_SIZE and FontTokens.DISPLAY_SIZE.
- Replaced old header with PageHeader({ title: '个人资料', showBack: true }).

RegisterPage/LoginPage: added design-time comments to reflect centered-brand layout.

Next steps: run verification (lint/build/tests) in a properly configured environment.
