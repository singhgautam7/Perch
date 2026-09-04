# Privacy Policy for Perch

**Last Updated:** September 4, 2026

**Developer:** Gautam Rajeev Singh  
**Application:** Perch — Link & Bookmark Manager

---

## 1. Overview & Core Philosophy

Perch is designed from the ground up to be **local-first, calm, and private**. Your saved links, reading lists, notes, tags, and folder structures belong exclusively to you. 

- **No Account Required:** You do not need to register, sign in, or create an account to use Perch.
- **No Remote Servers:** Perch does not operate any backend servers or central databases.
- **No Analytics, Tracking, or Ads:** Perch contains zero third-party advertising SDKs, tracking tools, or telemetry trackers.

---

## 2. Information Collected and Stored

### Local Storage on Your Device
All data created or imported into Perch is stored entirely on your device in a private local SQLite database. This includes:
- URLs and page titles
- Personal notes and checklists
- Custom tags and folder hierarchies
- Pinned and archived statuses
- Application preferences (theme, view modes, landing tab)

This data never leaves your device unless you explicitly use the local export feature.

### Data We Do NOT Collect
- We do not collect personally identifiable information (PII) such as your name, email address, physical address, or phone number.
- We do not track your browsing habits, location, or usage statistics.
- We do not log or store the URLs you save.

---

## 3. Network Usage & Device Permissions

Perch requires minimal device permissions to function as intended:

| Permission | Purpose |
| :--- | :--- |
| `android.permission.INTERNET` | When you add a new link or manually refresh metadata, Perch sends a direct HTTP `GET` request from your device to the target website to fetch title, description, and thumbnail previews (Open Graph metadata). |
| `android.permission.ACCESS_NETWORK_STATE` | Used solely to determine if your device is currently connected to a network before attempting to fetch metadata. |

> **Important:** Network requests for metadata fetching occur directly between your device and the destination website. No requests or URLs are routed through any intermediary server owned or managed by Perch.

---

## 4. Third-Party Services and SDKs

Perch does not integrate with any third-party analytics (e.g., Google Analytics, Firebase Analytics), advertising networks, or data brokers.

When you click an external link within Perch, it opens in your default web browser or external application. Those third-party websites operate under their own privacy policies.

---

## 5. Data Ownership, Export, and Deletion

- **Export:** You can export your complete database at any time from the Data screen in JSON, Netscape Bookmarks (HTML), or CSV formats.
- **Deletion:** You have full control over your data. You can delete individual links, folders, or tags at any time. Uninstalling the app will permanently remove all locally stored database files.

---

## 6. Children’s Privacy

Perch does not collect, solicit, or store personal information from anyone, including children under the age of 13 (or under 16 in certain jurisdictions).

---

## 7. Changes to This Privacy Policy

If this Privacy Policy is updated in the future, the revised version will be published here with an updated "Last Updated" date.

---

## 8. Contact Information

If you have any questions, feedback, or concerns regarding this Privacy Policy or Perch, please contact:

**Developer:** Gautam Rajeev Singh  
**Project:** Perch
