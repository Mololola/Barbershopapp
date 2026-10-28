from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

from app.core.rate_limit import limiter

router = APIRouter()

# Google Play requires a web page, reachable without the app, that explains
# how to delete an account and what is kept afterwards. The deletion itself
# stays in the app (DELETE /account), so this page only gives the steps and
# an email fallback for people who no longer have the app.
_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Delete your Fadra Cut account</title>
<style>
  body { font-family: -apple-system, Roboto, Arial, sans-serif; background: #EDEAE3; color: #221D1A;
         margin: 0; padding: 24px 16px; line-height: 1.5; }
  .card { max-width: 560px; margin: 0 auto; background: #FAF8F4; border: 1px solid #DCD5C6;
          border-radius: 16px; padding: 28px 24px; }
  h1 { font-size: 1.5rem; margin: 0 0 8px; }
  h2 { font-size: 1.1rem; margin: 24px 0 8px; }
  p, li { color: #4A4641; }
  ol, ul { padding-left: 22px; margin: 0; }
  li { margin-bottom: 6px; }
  a { color: #7A5B22; }
</style>
</head>
<body>
  <div class="card">
    <h1>Delete your Fadra Cut account</h1>
    <p>Fadra Cut is run by Luis Guillot Lozano. You can delete your account at any time.</p>

    <h2>In the app</h2>
    <ol>
      <li>Open Fadra Cut and sign in.</li>
      <li>Tap <strong>Settings</strong> (the gear icon at the top of the home screen).</li>
      <li>Tap <strong>Delete account</strong> and confirm.</li>
    </ol>
    <p>Your account is deleted straight away.</p>

    <h2>Without the app</h2>
    <p>Email <a href="mailto:luis.guillot.lozano@gmail.com?subject=Delete%20my%20Fadra%20Cut%20account">luis.guillot.lozano@gmail.com</a>
       from the email address you signed up with, asking us to delete your account. We'll do it within one month
       and reply to confirm.</p>

    <h2>What is deleted</h2>
    <p>Your profile, bookings, reviews, posts, photos and videos, messages, saved designs, and any rewards
       that haven't been paid to you yet.</p>

    <h2>What is kept</h2>
    <ul>
      <li>Records of reward withdrawals already paid to you (amount, date, account holder name and IBAN) are kept
          for 6 years, because tax law requires it.</li>
      <li>Stripe keeps its own records of payments for its legal obligations.</li>
    </ul>

    <h2>Business accounts</h2>
    <p>Before deleting a business account, cancel its subscription and resolve any upcoming bookings, so no customer
       loses an appointment without warning.</p>

    <p style="margin-top: 24px;">More detail is in our
       <a href="https://claude.ai/code/artifact/f348e6eb-ffe5-4615-8087-6ab8396295ca">Privacy Policy</a>.</p>
  </div>
</body>
</html>
"""


@router.get("/delete-account", response_class=HTMLResponse)
@limiter.exempt
def delete_account_page(request: Request) -> str:
    return _PAGE
