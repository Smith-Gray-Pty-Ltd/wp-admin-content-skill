# Plugin Module: LifterLMS [lifterlms]

## Overview
- **Plugin**: LifterLMS
- **Slug**: lifterlms
- **Website**: https://lifterlms.com/
- **Documentation**: https://developer.lifterlms.com/rest-api/
- **Primary Interface**: REST API (`/llms/v1/`) + WP-CLI (`wp llms`)

## What this plugin does
LifterLMS is a WordPress LMS (Learning Management System) plugin for creating and selling online courses, memberships, and training programs. It handles courses, lessons, quizzes, student enrollment, achievements, certificates, and ecommerce.

---

## Authentication

LifterLMS uses standard WordPress authentication. All REST requests use Application Passwords.

```bash
WP_SITE="https://example.com"
WP_USER="admin"
WP_APP_PASSWORD="abcd EFGH 1234 ijkl MNOP 5678"

curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/llms/v1/courses?per_page=5" | python3 -m json.tool
```

---

## Database Tables

| Table | Purpose |
|-------|---------|
| `wp_lifterlms_user_postmeta` | Student progress on courses/lessons |
| `wp_lifterlms_quiz_attempts` | Quiz attempt data |
| `wp_lifterlms_events` | Event log (enrollments, completions, etc.) |
| `wp_lifterlms_events_open_sessions` | Open event sessions |
| `wp_lifterlms_notifications` | Notification queue |
| `wp_lifterlms_product_to_access_plan` | Maps products to access plans |

LifterLMS also stores data in WordPress custom post types: `course`, `lesson`, `llms_quiz`, `llms_question`, `llms_membership`, `llms_access_plan`, `llms_order`, `llms_certificate`, `llms_achievement`.

---

## REST API Endpoints

Base path: `/wp-json/llms/v1/`

### Courses (`/courses`)

```bash
GET    /llms/v1/courses                                # List courses
GET    /llms/v1/courses?per_page=50                    # Paginate
GET    /llms/v1/courses?status=publish                 # Published only
POST   /llms/v1/courses                                # Create course
GET    /llms/v1/courses/{id}                           # Get course
PUT    /llms/v1/courses/{id}                           # Update course
DELETE /llms/v1/courses/{id}                           # Delete course
```

**Create a course**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Introduction to Web Development",
    "content": "Learn HTML, CSS, and JavaScript from scratch.",
    "status": "publish"
  }' \
  "$WP_SITE/wp-json/llms/v1/courses"
```

**Course properties**:
- `length` — estimated course length (e.g., "6 weeks")
- `difficulty` — beginner, intermediate, advanced
- `capacity` — max students (0 = unlimited)
- `capacity_message` — message when full
- `syllabus` — course outline/syllabus
- `course_track` — track term IDs
- `instructors` — instructor user IDs
- `restrictions` — enrollment restrictions array

### Lessons (`/lessons`)

```bash
GET    /llms/v1/lessons                                # List lessons
GET    /llms/v1/lessons?parent={course_id}             # Lessons in a course
POST   /llms/v1/lessons                                # Create lesson
PUT    /llms/v1/lessons/{id}                            # Update lesson
DELETE /llms/v1/lessons/{id}                            # Delete lesson
```

**Create a lesson in a course**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "HTML Fundamentals",
    "content": "Learn the basics of HTML markup.",
    "parent_course": 123,
    "order": 1,
    "free_lesson": true,
    "drip_method": "date",
    "drip_date": "2024-01-15T00:00:00",
    "status": "publish"
  }' \
  "$WP_SITE/wp-json/llms/v1/lessons"
```

**Lesson properties**:
- `parent_course` — course ID (required)
- `parent_section` — section ID (optional, for organizing within a course)
- `order` — position within the course
- `free_lesson` — preview lesson (no enrollment required)
- `drip_method` — `none`, `date`, `enrollment`, `start`, `prerequisite`
- `drip_date` — unlock date (for `date` method)
- `drip_days` — days after enrollment (for `enrollment` method)

### Sections (`/sections`)

```bash
GET    /llms/v1/sections                               # List sections
GET    /llms/v1/sections?parent={course_id}            # Sections in a course
POST   /llms/v1/sections                               # Create section
PUT    /llms/v1/sections/{id}                           # Update section
DELETE /llms/v1/sections/{id}                           # Delete section
```

**Create a section**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Module 1: Getting Started",
    "parent_course": 123,
    "order": 1
  }' \
  "$WP_SITE/wp-json/llms/v1/sections"
```

### Quizzes (`/quizzes`)

```bash
GET    /llms/v1/quizzes                                # List quizzes
GET    /llms/v1/quizzes?parent={lesson_id}             # Quizzes in a lesson
POST   /llms/v1/quizzes                                # Create quiz
PUT    /llms/v1/quizzes/{id}                            # Update quiz
DELETE /llms/v1/quizzes/{id}                            # Delete quiz
```

**Create a quiz**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "HTML Quiz",
    "parent_lesson": 456,
    "passing_percent": 70,
    "time_limit": 30,
    "allowed_attempts": 3
  }' \
  "$WP_SITE/wp-json/llms/v1/quizzes"
```

### Questions (`/questions`)

```bash
GET    /llms/v1/questions                              # List questions
GET    /llms/v1/questions?parent={quiz_id}             # Questions in a quiz
POST   /llms/v1/questions                              # Create question
PUT    /llms/v1/questions/{id}                          # Update question
DELETE /llms/v1/questions/{id}                          # Delete question
```

**Question types**: `choice` (multiple choice), `true_false`, `fill_in_the_blank`, `image` (image choice), `reorder`, `short_answer`, `long_answer`, `upload`, `code`, `scale`

**Create a multiple choice question**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "What does HTML stand for?",
    "question_type": "choice",
    "parent_id": 789,  // quiz ID
    "choices": [
      {"choice": "Hyper Text Markup Language", "correct": true, "marker": "A"},
      {"choice": "High Tech Modern Language", "correct": false, "marker": "B"},
      {"choice": "Home Tool Markup Language", "correct": false, "marker": "C"},
      {"choice": "Hyper Transfer Markup Language", "correct": false, "marker": "D"}
    ],
    "points": 1
  }' \
  "$WP_SITE/wp-json/llms/v1/questions"
```

TIP: Choices for image questions use the `choice` fields but also include `src` for the image URL.

### Memberships (`/memberships`)

```bash
GET    /llms/v1/memberships                            # List memberships
POST   /llms/v1/memberships                            # Create membership
PUT    /llms/v1/memberships/{id}                        # Update membership
DELETE /llms/v1/memberships/{id}                        # Delete membership
```

**Create a membership**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Premium Membership",
    "content": "Access all courses with a single membership.",
    "auto_enroll": [123, 456],
    "status": "publish"
  }' \
  "$WP_SITE/wp-json/llms/v1/memberships"
```

**Membership properties**:
- `auto_enroll` — array of course IDs to auto-enroll when purchased
- `restriction_redirect_type` — where to send restricted users
- `restriction_redirect_page_id` — page for redirect

### Access Plans (`/access-plans`)

```bash
GET    /llms/v1/access-plans                           # List all plans
GET    /llms/v1/access-plans?post_id={course_or_membership_id}  # Plans for a product
POST   /llms/v1/access-plans                           # Create plan
PUT    /llms/v1/access-plans/{id}                       # Update plan
DELETE /llms/v1/access-plans/{id}                       # Delete plan
```

**Create an access plan**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "One-Time Payment",
    "product_id": 123,  // course or membership ID
    "price": "199.00",
    "is_free": false,
    "frequency": 0,      // 0 = one-time, 1 = recurring
    "length": 0,          // 0 = lifetime, otherwise number of periods
    "period": "year",     // day, week, month, year
    "sku": "COURSE-001",
    "sale_price": "",
    "on_sale": false,
    "access_expiration": "lifetime",
    "access_period": 365,  // days of access
    "availability": "open",
    "visibility": "visible",
    "status": "publish"
  }' \
  "$WP_SITE/wp-json/llms/v1/access-plans"
```

### Orders (`/orders`)

```bash
GET    /llms/v1/orders                                 # List orders
GET    /llms/v1/orders?status=llms-completed           # Filter by status
GET    /llms/v1/orders?student={user_id}               # Student's orders
POST   /llms/v1/orders                                 # Create order
PUT    /llms/v1/orders/{id}                             # Update order
DELETE /llms/v1/orders/{id}                             # Delete order
```

**Order statuses**: `llms-pending`, `llms-processing`, `llms-completed`, `llms-cancelled`, `llms-failed`, `llms-refunded`, `llms-on-hold`

**Create a manual order for a student**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 5,
    "billing_first_name": "Jane",
    "billing_last_name": "Doe",
    "billing_email": "jane@example.com",
    "order_total": "199.00",
    "status": "llms-completed",
    "line_items": [
      {
        "product_id": 123,
        "access_plan_id": 456,
        "title": "Web Development Course",
        "type": "course",
        "price": "199.00",
        "quantity": 1
      }
    ]
  }' \
  "$WP_SITE/wp-json/llms/v1/orders"
```

### Students (`/students`)

```bash
GET    /llms/v1/students                               # List students
GET    /llms/v1/students/{id}                          # Get student details
GET    /llms/v1/students/{id}/enrollments              # Student enrollments
POST   /llms/v1/students/{id}/enrollments              # Enroll student
DELETE /llms/v1/students/{id}/enrollments/{eid}        # Unenroll student
GET    /llms/v1/students/{id}/progress/{post_id}       # Progress in a course/lesson
```

**Enroll a student in a course**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"post_id": 123}' \
  "$WP_SITE/wp-json/llms/v1/students/5/enrollments"
```

**Bulk enroll students**:
```bash
for USER_ID in 5 8 12 15 22; do
  curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
    -H "Content-Type: application/json" \
    -d "{\"post_id\": 123}" \
    "$WP_SITE/wp-json/llms/v1/students/$USER_ID/enrollments"
  echo "Enrolled user $USER_ID in course 123"
done
```

**Check student progress**:
```bash
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/llms/v1/students/5/progress/123" | python3 -c "
import json,sys
p=json.load(sys.stdin)
print(f'Overall: {p.get(\"progress\",0)}%')
print(f'Last activity: {p.get(\"last_activity\",\"never\")}')
print(f'Completed: {p.get(\"completed\",\"no\")}')"
```

### Student Quiz Attempts

```bash
GET    /llms/v1/students/{id}/quizzes/{quiz_id}/attempts   # Quiz attempts
POST   /llms/v1/students/{id}/quizzes/{quiz_id}/attempts   # Start attempt
PUT    /llms/v1/students/{id}/quizzes/{quiz_id}/attempts/{aid}  # Submit answers
```

### Certificates (`/certificates`)

```bash
GET    /llms/v1/certificates                           # List certificate templates
POST   /llms/v1/certificates                           # Create certificate template
GET    /llms/v1/certificates/{id}                      # Get certificate
PUT    /llms/v1/certificates/{id}                      # Update certificate
DELETE /llms/v1/certificates/{id}                      # Delete certificate
```

**Award a certificate to a student**:
```bash
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 5,
    "related_post_id": 123,  // course ID
    "certificate_template_id": 99
  }' \
  "$WP_SITE/wp-json/llms/v1/certificates/award"
```

### Achievements (`/achievements`)

```bash
GET    /llms/v1/achievements                           # List achievement templates
POST   /llms/v1/achievements                           # Create achievement
POST   /llms/v1/achievements/award                     # Award achievement to student
```

### Instructors (`/instructors`)

```bash
GET    /llms/v1/instructors                            # List instructors
GET    /llms/v1/instructors/{id}                       # Get instructor
GET    /llms/v1/instructors/{id}/courses               # Instructor's courses
```

### API Keys (`/api-keys`)

```bash
GET    /llms/v1/api-keys                               # List API keys
POST   /llms/v1/api-keys                               # Create API key
PUT    /llms/v1/api-keys/{id}                           # Update key
DELETE /llms/v1/api-keys/{id}                           # Delete key
```

### Webhooks (`/webhooks`)

```bash
GET    /llms/v1/webhooks                               # List webhooks
POST   /llms/v1/webhooks                               # Create webhook
PUT    /llms/v1/webhooks/{id}                           # Update webhook
DELETE /llms/v1/webhooks/{id}                           # Delete webhook
```

---

## WP-CLI Commands

```bash
wp llms course list --format=json
wp llms course create
wp llms course update 123
wp llms course delete 123

wp llms lesson list
wp llms lesson create
wp llms lesson update 123

wp llms quiz list
wp llms quiz create

wp llms question list
wp llms question create

wp llms membership list
wp llms membership create

wp llms student list
wp llms student enroll 5 --course=123
wp llms student unenroll 5 --course=123
wp llms student progress 5 --course=123

wp llms order list
wp llms order create

wp llms api-key list
wp llms api-key create
```

---

## Quick Reference: Common Tasks

### Build a Complete Course

```bash
# 1. Create the course
COURSE_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"title":"Python for Beginners","status":"publish"}' \
  "$WP_SITE/wp-json/llms/v1/courses" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

echo "Created course: $COURSE_ID"

# 2. Create sections (modules)
INTRO_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Getting Started\",\"parent_course\":$COURSE_ID,\"order\":1}" \
  "$WP_SITE/wp-json/llms/v1/sections" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

BASICS_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Python Basics\",\"parent_course\":$COURSE_ID,\"order\":2}" \
  "$WP_SITE/wp-json/llms/v1/sections" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 3. Create lessons in each section
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Installing Python\",\"content\":\"...\",\"parent_section\":$INTRO_ID,\"parent_course\":$COURSE_ID,\"order\":1,\"free_lesson\":true}" \
  "$WP_SITE/wp-json/llms/v1/lessons"

curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Variables and Data Types\",\"content\":\"...\",\"parent_section\":$BASICS_ID,\"parent_course\":$COURSE_ID,\"order\":1}" \
  "$WP_SITE/wp-json/llms/v1/lessons"

# 4. Create an access plan (pricing)
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"product_id\":$COURSE_ID,\"title\":\"One-Time Purchase\",\"price\":\"49.00\",\"frequency\":0,\"length\":0,\"status\":\"publish\"}" \
  "$WP_SITE/wp-json/llms/v1/access-plans"
```

### Add a Quiz to a Lesson

```bash
LESSON_ID=456

# 1. Create the quiz
QUIZ_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Chapter 1 Quiz\",\"parent_lesson\":$LESSON_ID,\"passing_percent\":75,\"time_limit\":20,\"allowed_attempts\":2}" \
  "$WP_SITE/wp-json/llms/v1/quizzes" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 2. Add questions
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"What is a variable?\",
    \"question_type\":\"choice\",
    \"parent_id\":$QUIZ_ID,
    \"points\":1,
    \"choices\":[
      {\"choice\":\"A named container for data\",\"correct\":true,\"marker\":\"A\"},
      {\"choice\":\"A fixed number\",\"correct\":false,\"marker\":\"B\"},
      {\"choice\":\"A type of function\",\"correct\":false,\"marker\":\"C\"}
    ]
  }" \
  "$WP_SITE/wp-json/llms/v1/questions"

curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\":\"Python is a statically typed language.\",
    \"question_type\":\"true_false\",
    \"parent_id\":$QUIZ_ID,
    \"points\":1,
    \"choices\":[
      {\"choice\":\"True\",\"correct\":false,\"marker\":\"A\"},
      {\"choice\":\"False\",\"correct\":true,\"marker\":\"B\"}
    ]
  }" \
  "$WP_SITE/wp-json/llms/v1/questions"
```

### Generate Student Progress Report

```bash
COURSE_ID=123

# Get all enrolled students
curl -s -u "$WP_USER:$WP_APP_PASSWORD" \
  "$WP_SITE/wp-json/llms/v1/students?enrolled_in=$COURSE_ID&per_page=100" | python3 -c "
import json,sys,urllib.request,base64

students=json.load(sys.stdin)
auth=base64.b64encode(b'$WP_USER:$WP_APP_PASSWORD').decode()

for s in students:
    uid=s['id']
    print(f'Student: {s[\"name\"]} ({s[\"email\"]})')
    print(f'  Registered: {s[\"registered_date\"]}')

    # Get progress (you'd curl this in a real script)
    print(f'  Last Activity: check /llms/v1/students/{uid}/progress/$COURSE_ID')
    print()
"

# Alternatively with WP-CLI
for UID in $(wp llms student list --enrolled_in=123 --field=id); do
  echo "=== Student $UID ==="
  wp llms student progress "$UID" --course=123 --format=json
done
```

### Mass Unenroll Students (Course Reset)

```bash
COURSE_ID=123

# Get all enrollments
STUDENT_IDS=$(wp llms student list --enrolled_in="$COURSE_ID" --field=id)

for UID in $STUDENT_IDS; do
  wp llms student unenroll "$UID" --course="$COURSE_ID"
  echo "Unenrolled student $UID from course $COURSE_ID"
done

echo "All students unenrolled. Course is reset."
```

### Create a Membership with Auto-Enrollment

```bash
# Create membership
MEMBERSHIP_ID=$(curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "title":"All-Access Pass",
    "content":"Get access to all our courses.",
    "auto_enroll":[123, 456, 789],
    "status":"publish"
  }' \
  "$WP_SITE/wp-json/llms/v1/memberships" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# Create access plan
curl -s -X POST -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"product_id\":$MEMBERSHIP_ID,
    \"title\":\"Monthly Subscription\",
    \"price\":\"29.99\",
    \"frequency\":1,
    \"length\":0,
    \"period\":\"month\",
    \"status\":\"publish\"
  }" \
  "$WP_SITE/wp-json/llms/v1/access-plans"

echo "Created membership $MEMBERSHIP_ID with monthly recurring access plan"
```

---

## Workflows & Patterns

### Course Content Drip Setup

```bash
COURSE_ID=123

# Lesson 1: Available immediately
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"drip_method":"none"}' \
  "$WP_SITE/wp-json/llms/v1/lessons/100"

# Lesson 2: Available 3 days after enrollment
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"drip_method":"enrollment","drip_days":3}' \
  "$WP_SITE/wp-json/llms/v1/lessons/101"

# Lesson 3: Available on a specific date
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"drip_method":"date","drip_date":"2024-03-01T00:00:00"}' \
  "$WP_SITE/wp-json/llms/v1/lessons/102"

# Lesson 4: Available only after completing lesson 2
curl -s -X PUT -u "$WP_USER:$WP_APP_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"drip_method":"prerequisite","prerequisite":101}' \
  "$WP_SITE/wp-json/llms/v1/lessons/103"
```

---

## Troubleshooting

- **"Student not found" on enrollment**: The user must exist as a WordPress user first. Create the user with `wp user create` or use the customer creation flow before enrollment.
- **Course progress not updating**: Check that the lesson has `"free_lesson":false` and the student is properly enrolled. Check `wp_lifterlms_user_postmeta` for orphaned records.
- **Access plan not showing on course page**: Verify the access plan `status` is `publish` and `visibility` is `visible`. Check that the course has `"enrollment_open":true`.
- **Quiz grades not saving**: Quiz must be properly linked to a lesson (`parent_lesson`), and the student must have an active enrollment.
- **"llms_rest_cannot_view" error**: The user needs the `manage_lifterlms` capability or must be logged in as a student (for student-scoped endpoints). Use an Administrator-level account for admin operations.
