/// The published Terms of Service and Privacy Policy (sources:
/// docs/terms-of-service.html and docs/privacy-policy.html).
const termsOfServiceUrl = 'https://claude.ai/code/artifact/7b0fd848-a548-46c4-9ee1-89d93f7e7b26';
const privacyPolicyUrl = 'https://claude.ai/code/artifact/f348e6eb-ffe5-4615-8087-6ab8396295ca';

/// The effective date on both documents. When either changes materially,
/// update this and [policyChangeSummary] together: every signed-in user who
/// accepted an older version is told once (see PolicyUpdateNotice).
final policiesEffective = DateTime.utc(2026, 10, 15);

const policyChangeSummary =
    'Rewards not yet paid out are given up if you delete your account (you\'re offered a cash-out first), and '
    'records of rewards already paid to you are kept for 6 years for tax purposes.';
