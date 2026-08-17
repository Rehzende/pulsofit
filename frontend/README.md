# Personal AI - Frontend

A modern, responsive web application for the Personal AI fitness platform. Built with Next.js 16, React 19, and Tailwind CSS 4.

## 🚀 Tech Stack

- **Framework:** [Next.js 16](https://nextjs.org/) (App Router)
- **UI Library:** [React 19](https://react.dev/)
- **Styling:** [Tailwind CSS 4](https://tailwindcss.com/)
- **Components:** [Radix UI](https://www.radix-ui.com/) (Headless UI primitives)
- **Icons:** [Lucide React](https://lucide.dev/)
- **Animations:** [Framer Motion](https://www.framer.com/motion/)
- **HTTP Client:** [Axios](https://axios-http.com/)
- **Utilities:** `date-fns`, `clsx`, `tailwind-merge`

## ✨ Features

### 🏋️ Student Dashboard
- **Workout Management:** View assigned workouts, track progress, and view history.
- **Live Workout Runner:** Real-time workout tracking with set/rep logging.
- **Progress Tracking:** Visual charts for weight, reps, and consistency.
- **Profile:** Manage personal details and settings.

### 👨‍🏫 Trainer Dashboard
- **Student Management:** Invite and manage students.
- **Workout Builder:** Create and assign custom workouts to students.
- **Analytics:** View student performance and engagement stats.
- **Brand Customization:** Customize the app appearance (logo, colors) for your students.

### 🛡️ Admin Dashboard
- **Trainer Management:** Invite, approve, and manage trainers.
- **System Overview:** View platform statistics (active users, revenue).
- **Subscription Plans:** Manage pricing and features.

## 🛠️ Getting Started

### Prerequisites
- Node.js 18+ 
- npm, yarn, pnpm, or bun

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

3. Configure Environment Variables:
   Create a `.env.local` file in the root directory and add:
   ```env
   NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
   ```

4. Run the development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## 📂 Project Structure

```
src/
├── app/              # Next.js App Router pages and layouts
│   ├── (auth)/       # Authentication routes (login, register)
│   ├── (dashboard)/  # Protected dashboard routes
│   ├── admin/        # Admin specific routes
│   └── layout.tsx    # Root layout
├── components/       # Reusable UI components
│   ├── ui/           # Base UI components (buttons, inputs, etc.)
│   └── layouts/      # Layout components (sidebar, header)
├── lib/              # Utilities and API clients
│   ├── api.ts        # Axios instance and API methods
│   └── utils.ts      # Helper functions
└── styles/           # Global styles
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
