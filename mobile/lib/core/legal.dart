/// The published Terms of Service and Privacy Policy (sources:
/// docs/terms-of-service.html and docs/privacy-policy.html).
const termsOfServiceUrl = 'https://claude.ai/code/artifact/7b0fd848-a548-46c4-9ee1-89d93f7e7b26';
const privacyPolicyUrl = 'https://claude.ai/code/artifact/f348e6eb-ffe5-4615-8087-6ab8396295ca';

/// The effective date on both documents. When either changes materially,
/// update this and [policyChangeSummary] together: every signed-in user who
/// accepted an older version is told once (see PolicyUpdateNotice).
final policiesEffective = DateTime.utc(2026, 10, 13);

const policyChangeSummary =
    'If a shop\'s subscription payment fails, the shop stays visible to customers for 3 days, is then hidden '
    'until it pays, and is deleted 60 days after the first failed payment.';
