import axios from 'axios';

let apiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.pulsofit.app/api/v1';

// Normalize the URL: remove trailing slash, then ensure it ends with /api/v1
apiUrl = apiUrl.replace(/\/$/, ''); // Remove trailing slash
if (!apiUrl.endsWith('/api/v1')) {
    apiUrl = apiUrl + '/api/v1';
}

const API_URL = apiUrl;

export const api = axios.create({
    baseURL: API_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Add a request interceptor to inject the token
api.interceptors.request.use(
    (config) => {
        if (typeof window !== 'undefined') {
            const token = localStorage.getItem('token');
            if (token) {
                config.headers.Authorization = `Bearer ${token}`;
            }
        }
        return config;
    },
    (error) => Promise.reject(error)
);

// Add a response interceptor to handle token refresh
api.interceptors.response.use(
    (response) => response,
    async (error) => {
        const originalRequest = error.config;
        if (error.response?.status === 401 && !originalRequest._retry) {
            originalRequest._retry = true;
            try {
                const refreshToken = localStorage.getItem('refresh_token');
                if (refreshToken) {
                    const response = await axios.post(`${API_URL}/refresh-token`, null, {
                        params: { refresh_token: refreshToken }
                    });
                    const { access_token, refresh_token: new_refresh_token } = response.data;
                    localStorage.setItem('token', access_token);
                    if (new_refresh_token) {
                        localStorage.setItem('refresh_token', new_refresh_token);
                    }
                    originalRequest.headers.Authorization = `Bearer ${access_token}`;
                    return api(originalRequest);
                } else {
                    // No refresh token — clear session and send the user to login
                    // instead of leaving them stuck on a broken 401.
                    localStorage.removeItem('token');
                    if (typeof window !== 'undefined') {
                        window.location.href = '/login';
                    }
                }
            } catch (refreshError) {
                console.error("Token refresh failed:", refreshError);
                localStorage.removeItem('token');
                localStorage.removeItem('refresh_token');
                if (typeof window !== 'undefined') {
                    window.location.href = '/login';
                }
            }
        }
        return Promise.reject(error);
    }
);

// ── Types ─────────────────────────────────────────────────────

export type NotificationType =
  | 'HIRING_REQUEST' | 'HIRING_ACCEPTED' | 'HIRING_REJECTED'
  | 'NEW_REVIEW' | 'NEW_WORKOUT' | 'STREAK_WARNING' | 'STUDENT_TRAINING';

export interface AppNotification {
  id: string;
  user_id: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, unknown>;
  is_read: boolean;
  created_at: string;
}

export interface User {
    id: string;
    email: string;
    full_name?: string;
    birthday?: string;
    photo_url?: string;
    whatsapp_number?: string;
    role: 'STUDENT' | 'TRAINER' | 'SUPER_ADMIN';
    is_active: boolean;
    xp_points: number;
    current_streak: number;
    level: number;
    resting_hr?: number | null;
    max_hr?: number | null;
    medical_history?: Record<string, unknown>;
    subscription_status?: string;
    subscription_end_date?: string;
    plan_id?: string;
    trainer_id?: string;
    trainer_profile?: TrainerProfile;
    trainer_brand_name?: string;
    trainer_logo_url?: string;
    trainer_primary_color?: string;
    trainer_whatsapp_number?: string;
    invite_status?: string;
    invite_link?: string;
    anamnesis_completed?: boolean;
    accepted_ai_terms_at?: string;
    last_login_at?: string;
}

export interface TrainerProfile {
    id: string;
    user_id: string;
    slug?: string;
    brand_name?: string;
    logo_url?: string;
    primary_color?: string;
    whatsapp_number?: string;
    bio?: string;
    modality?: 'presencial' | 'online' | 'hibrido';
    specialties?: string[] | string;
    gyms?: string[];
    hourly_rate?: number | string;
    enable_iot: boolean;
    enable_ai_vision: boolean;
    enable_ai_workouts: boolean;
    is_verified: boolean;
    is_available_for_hire?: boolean;
}

export interface HiringRequest {
    id: string;
    student_id: string;
    trainer_id: string;
    status: 'PENDING' | 'ACCEPTED' | 'REJECTED';
    created_at: string;
    student_name?: string;
    student_photo?: string;
}

export interface SubscriptionPlan {
    id: string;
    name: string;
    price: number;
    max_students: number;
    features?: { ai_workouts?: boolean; iot_enabled?: boolean };
    is_active?: boolean;
}

export interface StudentEngagement {
    student_id: string;
    student_name: string;
    student_email: string;
    photo_url?: string;
    current_streak: number;
    sessions_last_7_days: number;
    days_since_last_session: number | null;
    last_session_date: string | null;
    risk_level: 'AT_RISK' | 'IRREGULAR' | 'ON_TRACK';
    engagement_score: number;
    upcoming_workouts_count: number;
}

export interface Exercise {
    name: string;
    category: string;
    is_iot_compatible: boolean;
    id: string;
    muscle_group?: string;
    met_value?: number;
    video_url?: string;
    description?: string;
    equipment_photo_url?: string;
}

export interface ExerciseGroupItem {
    id: string;
    exercise_id: string;
    order_index: number;
    sets: number;
    reps_min?: number | null;
    reps_max?: number | null;
    duration_seconds?: number | null;
    rest_seconds: number;
    exercise?: Exercise;
}

export interface ExerciseGroup {
    id: string;
    name: string;
    description?: string | null;
    items: ExerciseGroupItem[];
}

export interface WorkoutGroup {
    id: string;
    name: string;
    trainer_id: string;
    student_id?: string | null;
    trainer_name?: string | null;
    created_at: string;
    start_date?: string | null;
    end_date?: string | null;
    is_active?: boolean;
}

export interface WorkoutItem {
    sets: number;
    reps_min?: number | null;
    reps_max?: number | null;
    reps_per_set?: number[] | null;
    rest_seconds: number;
    notes?: string | null;
    target_zone_min_bpm?: number | null;
    target_zone_max_bpm?: number | null;
    target_rpe?: number | null;
    id: string;
    workout_id: string;
    exercise_id: string;
    exercise_name?: string;
    superset_id?: string | null;
    video_url?: string | null;
    equipment_photo_url?: string | null;
}

export interface Workout {
    name: string;
    scheduled_for?: string | null;
    start_date?: string | null;
    end_date?: string | null;
    id: string;
    user_id: string;
    group_id?: string | null;
    is_favorite?: boolean;
    items: WorkoutItem[];
    sessions?: WorkoutSession[];
}

export interface WorkoutItemCreate {
    sets: number;
    reps_min?: number | null;
    reps_max?: number | null;
    reps_per_set?: number[] | null;
    duration_seconds?: number | null;
    rest_seconds: number;
    notes?: string | null;
    target_zone_min_bpm?: number | null;
    target_zone_max_bpm?: number | null;
    target_rpe?: number | null;
    exercise_name?: string | null;
    exercise_id?: string | null;
    superset_id?: string | null;
}

export interface WorkoutCreate {
    name: string;
    scheduled_for?: string | null;
    start_date?: string | null;
    end_date?: string | null;
    student_id: string;
    items: WorkoutItemCreate[];
    group_id?: string | null;
}

export interface WorkoutUpdate {
    name?: string;
    scheduled_for?: string | null;
    start_date?: string | null;
    end_date?: string | null;
    items?: WorkoutItemCreate[];
    group_id?: string | null;
}

export interface WorkoutSession {
    id: string;
    workout_id: string;
    user_id: string;
    start_time: string;
    end_time?: string | null;
    status: 'STARTED' | 'FINISHED' | 'ABANDONED' | 'DRAFT';
    shareable_image_url?: string | null;
    progress_data?: Record<string, unknown>;
    last_activity_time?: string | null;
    average_heart_rate?: number | null;
    xp_earned?: number | null;
    workout?: Workout;
}

export interface WorkoutSessionFinishResponse {
    message: string;
    session_id: string;
    xp_earned: number;
    new_total_xp: number;
    share_context: {
        brand_primary_color: string;
        brand_logo_url: string | null;
        stats: {
            duration_minutes: number;
            calories: number;
            zone_minutes: number;
        };
    };
}

export interface GenExercise {
    exercise_name: string;
    sets: number;
    reps_min: number | null;
    reps_max: number | null;
    duration_seconds: number | null;
    rest_seconds: number;
    notes: string;
    methodology_type?: string;
    methodology_params?: Record<string, unknown>;
}

export interface GenWorkout {
    name: string;
    notes: string;
    exercises: GenExercise[];
}

export enum AgentActionStatus {
    PENDING = "PENDING",
    APPROVED = "APPROVED",
    REJECTED = "REJECTED",
    EXECUTED = "EXECUTED"
}

export interface AgentMessage {
    id: string;
    session_id: string;
    role: "user" | "model" | "system";
    content?: string | null;
    tool_calls?: unknown[] | null;
    action_data?: { type?: string; actions?: unknown[]; payload?: Record<string, unknown>; [key: string]: unknown } | null;
    action_status?: AgentActionStatus | null;
    created_at: string;
}

export interface AgentSession {
    id: string;
    trainer_id: string;
    title: string;
    is_active: boolean;
    created_at: string;
    updated_at: string;
    messages: AgentMessage[];
}

export interface TrainerMarketplaceItem {
    user_id: string;
    full_name: string;
    photo_url?: string;
    brand_name?: string;
    logo_url?: string;
    bio?: string;
    modality?: 'presencial' | 'online' | 'hibrido';
    specialties?: string[];
    gyms?: string[];
    hourly_rate?: number;
    whatsapp_number?: string;
    primary_color?: string;
    email?: string;
    request_status?: string;
    average_rating?: number;
    total_reviews?: number;
}

export interface Review {
    id: string;
    trainer_id: string;
    student_id?: string;
    student_name?: string;
    student_photo?: string;
    rating: number;
    text?: string;
    created_at: string;
}

export interface ReviewStats {
    average_rating: number;
    total_reviews: number;
    reviews: Review[];
}

// ── API Methods ───────────────────────────────────────────────

export const ApiClient = {
    getAllUsers: async (): Promise<User[]> => {
        const response = await api.get<User[]>('/admin/users');
        return response.data;
    },

    promoteToTrainer: async (userId: string): Promise<User> => {
        const response = await api.post<User>(`/admin/users/${userId}/promote-to-trainer`);
        return response.data;
    },

    deleteUser: async (userId: string): Promise<void> => {
        await api.delete(`/admin/users/${userId}`);
    },

    getMe: async (): Promise<User> => {
        const response = await api.get<User>('/users/me');
        return response.data;
    },

    updateMe: async (data: Record<string, unknown>): Promise<User> => {
        const response = await api.put<User>('/users/me', data);
        return response.data;
    },

    acceptAiTerms: async (): Promise<User> => {
        const response = await api.post<User>('/users/accept-ai-terms');
        return response.data;
    },

    getStudents: async (): Promise<User[]> => {
        const response = await api.get<User[]>('/users/students');
        return response.data;
    },

    getStudent: async (id: string): Promise<User> => {
        const response = await api.get<User>(`/users/students/${id}`);
        return response.data;
    },

    getStudentStats: async (): Promise<{ xp_points: number; current_streak: number; best_streak: number; level: number; personal_bests: unknown[] }> => {
        const response = await api.get('/student/stats');
        return response.data;
    },

    createWorkout: async (data: WorkoutCreate): Promise<Workout> => {
        const response = await api.post<Workout>('/workouts/', data);
        return response.data;
    },

    updateWorkout: async (id: string, data: WorkoutUpdate): Promise<Workout> => {
        const response = await api.put<Workout>(`/workouts/${id}`, data);
        return response.data;
    },

    getWorkouts: async (studentId?: string): Promise<Workout[]> => {
        const params = studentId ? { student_id: studentId } : {};
        const response = await api.get<Workout[]>('/workouts/', { params });
        return response.data;
    },

    getWorkout: async (id: string): Promise<Workout> => {
        const response = await api.get<Workout>(`/workouts/${id}`);
        return response.data;
    },

    deleteWorkout: async (id: string): Promise<void> => {
        await api.delete(`/workouts/${id}`);
    },

    getExercises: async (): Promise<Exercise[]> => {
        const response = await api.get<Exercise[]>('/exercises/', { params: { limit: 1000 } });
        return response.data;
    },

    createExercise: async (data: Record<string, unknown>): Promise<Exercise> => {
        const response = await api.post<Exercise>('/exercises/', data);
        return response.data;
    },

    updateExercise: async (id: string, data: Record<string, unknown>): Promise<Exercise> => {
        const response = await api.put<Exercise>(`/exercises/${id}`, data);
        return response.data;
    },

    getWorkoutGroups: async (studentId?: string): Promise<WorkoutGroup[]> => {
        const response = await api.get<WorkoutGroup[]>('/workout-groups/', {
            params: studentId ? { student_id: studentId } : undefined,
        });
        return response.data;
    },

    createWorkoutGroup: async (
        name: string,
        opts?: { student_id?: string; start_date?: string | null; end_date?: string | null }
    ): Promise<WorkoutGroup> => {
        const response = await api.post<WorkoutGroup>('/workout-groups/', { name, ...opts });
        return response.data;
    },

    updateWorkoutGroup: async (
        id: string,
        data: { name?: string; start_date?: string | null; end_date?: string | null }
    ): Promise<WorkoutGroup> => {
        const response = await api.put<WorkoutGroup>(`/workout-groups/${id}`, data);
        return response.data;
    },

    archiveWorkoutGroup: async (id: string): Promise<WorkoutGroup> => {
        const response = await api.patch<WorkoutGroup>(`/workout-groups/${id}/archive`);
        return response.data;
    },

    unarchiveWorkoutGroup: async (id: string): Promise<WorkoutGroup> => {
        const response = await api.patch<WorkoutGroup>(`/workout-groups/${id}/unarchive`);
        return response.data;
    },

    deleteWorkoutGroup: async (id: string): Promise<void> => {
        await api.delete(`/workout-groups/${id}`);
    },

    getWeeklyStatus: async (): Promise<{ completed_days: number[], today_completed: boolean, next_workout: Workout | null }> => {
        const response = await api.get<{ completed_days: number[], today_completed: boolean, next_workout: Workout | null }>('/workouts/weekly-status');
        return response.data;
    },

    login: async (username: string, password: string): Promise<{ access_token: string, token_type: string, refresh_token: string }> => {
        const formData = new URLSearchParams();
        formData.append('username', username);
        formData.append('password', password);
        const response = await api.post<{ access_token: string, token_type: string, refresh_token: string }>('/login/access-token', formData, {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });
        if (response.data.refresh_token && typeof window !== 'undefined') {
            localStorage.setItem('refresh_token', response.data.refresh_token);
        }
        return response.data;
    },

    requestMagicLink: async (email: string): Promise<{ message: string }> => {
        if (typeof window !== 'undefined') {
            localStorage.setItem('pending_email', email.trim().toLowerCase());
        }
        const response = await api.post<{ message: string }>('/auth/magic-link', { email });
        return response.data;
    },

    verifyMagicLink: async (token: string): Promise<{ access_token: string, token_type: string, refresh_token: string }> => {
        const email = typeof window !== 'undefined' ? localStorage.getItem('pending_email') : null;
        const response = await api.post<{ access_token: string, token_type: string, refresh_token: string }>('/auth/verify-magic-link', { 
            token,
            email: email || undefined
        });
        if (response.data.refresh_token && typeof window !== 'undefined') {
            localStorage.setItem('refresh_token', response.data.refresh_token);
        }
        return response.data;
    },

    // Invites
    createInvite: async (email: string): Promise<{ invite_link: string }> => {
        const response = await api.post('/invites/', { email });
        return response.data;
    },

    getInvite: async (token: string): Promise<{ email: string; trainer_name?: string }> => {
        const response = await api.get(`/invites/${token}`);
        return response.data;
    },

    deleteInvite: async (id: string): Promise<void> => {
        await api.delete(`/invites/${id}`);
    },

    // Workout Session Endpoints
    startWorkoutSession: async (workoutId: string): Promise<WorkoutSession> => {
        const response = await api.post<WorkoutSession>('/workout-sessions/start', { workout_id: workoutId });
        return response.data;
    },

    finishWorkoutSession: async (sessionId: string, data: { end_time: string; status: string }): Promise<WorkoutSessionFinishResponse> => {
        const response = await api.post<WorkoutSessionFinishResponse>(`/workout-sessions/${sessionId}/finish`, data);
        return response.data;
    },

    updateSessionProgress: async (sessionId: string, progressData: Record<string, unknown>) => {
        const response = await api.patch(`/gamification/${sessionId}/progress`, progressData);
        return response.data;
    },

    getDraftSessions: async (): Promise<WorkoutSession[]> => {
        const response = await api.get<WorkoutSession[]>('/gamification/drafts');
        return response.data;
    },

    // Challenge
    startChallenge: async (): Promise<unknown> => {
        const response = await api.post('/gamification/challenge/start');
        return response.data;
    },

    getChallengeStatus: async (): Promise<{ active: boolean; days_completed: number; completed: boolean; started_at: string | null; completed_at: string | null }> => {
        const response = await api.get('/gamification/challenge/status');
        return response.data;
    },

    getHistory: async (): Promise<WorkoutSession[]> => {
        const response = await api.get<WorkoutSession[]>('/workout-sessions/history');
        return response.data;
    },

    getStudentHistory: async (studentId: string): Promise<WorkoutSession[]> => {
        const response = await api.get<WorkoutSession[]>(`/workout-sessions/student/${studentId}/history`);
        return response.data;
    },

    aiAgent: {
        getSessions: async (): Promise<AgentSession[]> => {
            const response = await api.get<AgentSession[]>('/ai-agent/sessions');
            return response.data;
        },
        getSession: async (sessionId: string): Promise<AgentSession> => {
            const response = await api.get<AgentSession>(`/ai-agent/session/${sessionId}`);
            return response.data;
        },
        createOrGetSession: async (forceNew = false): Promise<AgentSession> => {
            const response = await api.post<AgentSession>('/ai-agent/session', null, {
                params: { force_new: forceNew }
            });
            return response.data;
        },
        sendMessage: async (sessionId: string, message: string): Promise<AgentMessage> => {
            const response = await api.post<AgentMessage>('/ai-agent/chat', {
                session_id: sessionId,
                message: message
            });
            return response.data;
        },
        executeAction: async (messageId: string, action: 'approve' | 'reject'): Promise<AgentMessage> => {
            const response = await api.post<AgentMessage>('/ai-agent/execute-action', {
                message_id: messageId,
                action: action
            });
            return response.data;
        }
    },

    // Reviews
    createReview: async (data: { trainer_id: string; rating: number; text?: string }): Promise<Review> => {
        const response = await api.post<Review>('/reviews/', data);
        return response.data;
    },

    getTrainerReviews: async (trainerId: string): Promise<ReviewStats> => {
        const response = await api.get<ReviewStats>(`/reviews/trainer/${trainerId}`);
        return response.data;
    },

    getMyReview: async (trainerId: string): Promise<Review | null> => {
        const response = await api.get<Review | null>(`/reviews/my-review/${trainerId}`);
        return response.data;
    },

    trainer: {
        getStats: async (studentId?: string): Promise<unknown> => {
            const params = studentId ? { student_id: studentId } : {};
            const response = await api.get<unknown>('/trainer/stats', { params });
            return response.data;
        },
        getEngagement: async (): Promise<StudentEngagement[]> => {
            const response = await api.get<StudentEngagement[]>('/trainer/engagement');
            return response.data;
        },
        updateProfile: async (data: Record<string, unknown>): Promise<unknown> => {
            const response = await api.put<unknown>('/trainer/profile', data);
            return response.data;
        },
        uploadLogo: async (file: File, type: 'logo' | 'avatar' = 'logo'): Promise<{ logo_url: string; message: string }> => {
            const formData = new FormData();
            formData.append('file', file);
            const response = await api.post<{ logo_url: string; message: string }>(`/uploads/logo?type=${type}`, formData, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });
            return response.data;
        },
    },

    // Marketplace
    getMarketplaceTrainers: async (params?: { specialty?: string; name?: string }): Promise<TrainerMarketplaceItem[]> => {
        const response = await api.get<TrainerMarketplaceItem[]>('/marketplace/trainers', { params });
        return response.data;
    },

    getTrainerProfile: async (trainerId: string): Promise<TrainerMarketplaceItem> => {
        const response = await api.get<TrainerMarketplaceItem>(`/marketplace/trainers/${trainerId}`);
        return response.data;
    },

    requestTrainer: async (trainerId: string): Promise<unknown> => {
        const response = await api.post(`/marketplace/request/${trainerId}`);
        return response.data;
    },

    getPublicTrainerProfile: async (slugOrId: string): Promise<TrainerMarketplaceItem> => {
        const response = await api.get<TrainerMarketplaceItem>(`/public/trainers/${slugOrId}`);
        return response.data;
    },

    getHiringRequests: async (): Promise<HiringRequest[]> => {
        const response = await api.get<HiringRequest[]>('/marketplace/requests');
        return response.data;
    },

    acceptHiringRequest: async (requestId: string): Promise<HiringRequest> => {
        const response = await api.put<HiringRequest>(`/marketplace/request/${requestId}/accept`);
        return response.data;
    },

    rejectHiringRequest: async (requestId: string): Promise<HiringRequest> => {
        const response = await api.put<HiringRequest>(`/marketplace/request/${requestId}/reject`);
        return response.data;
    },

    // Admin Endpoints
    admin: {
        getTrainers: async (): Promise<User[]> => {
            const response = await api.get<User[]>('/admin/trainers');
            return response.data;
        },
        toggleTrainerStatus: async (trainerId: string, isActive: boolean): Promise<User> => {
            const response = await api.patch<User>(`/admin/trainers/${trainerId}/status`, { is_active: isActive });
            return response.data;
        },
        toggleTrainerIoT: async (trainerId: string, iotEnabled: boolean): Promise<User> => {
            const response = await api.patch<User>(`/admin/trainers/${trainerId}/iot`, { iot_enabled: iotEnabled });
            return response.data;
        },
        createTrainer: async (data: Record<string, unknown>): Promise<User> => {
            const response = await api.post<User>('/admin/trainers', data);
            return response.data;
        },
        getTrainer: async (id: string): Promise<User> => {
            const response = await api.get<User>(`/admin/trainers/${id}`);
            return response.data;
        },
        updateTrainer: async (id: string, data: Record<string, unknown>): Promise<User> => {
            const response = await api.patch<User>(`/admin/trainers/${id}`, data);
            return response.data;
        },
        deleteTrainer: async (id: string): Promise<void> => {
            await api.delete(`/admin/trainers/${id}`);
        },
        verifyTrainer: async (trainerId: string): Promise<User> => {
            const response = await api.patch<User>(`/admin/trainers/${trainerId}/verify`);
            return response.data;
        },
        assignTrainerPlan: async (trainerId: string, planId: string): Promise<User> => {
            const response = await api.patch<User>(`/admin/trainers/${trainerId}/plan`, { plan_id: planId });
            return response.data;
        },
        getPlans: async (): Promise<SubscriptionPlan[]> => {
            const response = await api.get<SubscriptionPlan[]>('/admin/plans/');
            return response.data;
        },
        createPlan: async (data: Record<string, unknown>): Promise<SubscriptionPlan> => {
            const response = await api.post<SubscriptionPlan>('/admin/plans/', data);
            return response.data;
        },
        updatePlan: async (id: string, data: Record<string, unknown>): Promise<SubscriptionPlan> => {
            const response = await api.put<SubscriptionPlan>(`/admin/plans/${id}`, data);
            return response.data;
        },
        getStats: async (): Promise<unknown> => {
            const response = await api.get<unknown>('/admin/stats');
            return response.data;
        },
        inviteTrainer: async (email: string): Promise<unknown> => {
            const response = await api.post('/invites/admin/trainer', { email });
            return response.data;
        }
    },

    notifications: {
        getAll: async (skip = 0, limit = 30): Promise<AppNotification[]> => {
            const response = await api.get<AppNotification[]>('/notifications/', { params: { skip, limit } });
            return response.data;
        },
        getUnreadCount: async (): Promise<number> => {
            const response = await api.get<{ unread_count: number }>('/notifications/unread-count');
            return response.data.unread_count;
        },
        markRead: async (id: string): Promise<void> => {
            await api.put(`/notifications/${id}/read`);
        },
        markAllRead: async (): Promise<void> => {
            await api.put('/notifications/read-all');
        },
    },

    // Trainer self-service plan methods
    getPublicPlans: async (): Promise<SubscriptionPlan[]> => {
        const response = await api.get<SubscriptionPlan[]>('/admin/plans/public');
        return response.data;
    },

    requestPlanChange: async (planId: string): Promise<{ message: string; plan_id: string }> => {
        const response = await api.post<{ message: string; plan_id: string }>('/admin/plans/request-change', null, {
            params: { plan_id: planId }
        });
        return response.data;
    },

    registerTrainer: async (data: Record<string, unknown>): Promise<{ access_token: string, token_type: string, refresh_token: string }> => {
        const response = await api.post<{ access_token: string, token_type: string, refresh_token: string }>('/register-trainer', data);

        if (response.data.refresh_token && typeof window !== 'undefined') {
            localStorage.setItem('refresh_token', response.data.refresh_token);
        }

        return response.data;
    },
};

// ── Standalone Exports for specific screens ──────────────────

export const getExercises = () => api.get<Exercise[]>('/exercises/', { params: { limit: 1000 } }).then(r => r.data);
export const createExercise = (data: Record<string, unknown>) => api.post<Exercise>('/exercises/', data).then(r => r.data);
export const updateExercise = (id: string, data: Record<string, unknown>) => api.put<Exercise>(`/exercises/${id}`, data).then(r => r.data);

export const getFavoriteExerciseIds = () => api.get<string[]>('/exercises/favorites/ids').then(r => r.data);
export const toggleFavoriteExercise = (exerciseId: string) => api.post<{ exercise_id: string; is_favorite: boolean }>(`/exercises/${exerciseId}/favorite`).then(r => r.data);

export const getExerciseGroups = () => api.get<ExerciseGroup[]>('/exercise-groups/').then(r => r.data);
export const createExerciseGroup = (data: { name: string; description?: string }) => api.post<ExerciseGroup>('/exercise-groups/', data).then(r => r.data);
export const updateExerciseGroup = (id: string, data: { name?: string; description?: string }) => api.put<ExerciseGroup>(`/exercise-groups/${id}`, data).then(r => r.data);
export const deleteExerciseGroup = (id: string) => api.delete(`/exercise-groups/${id}`).then(r => r.data);

export const addExerciseGroupItem = (groupId: string, data: Record<string, unknown>) => api.post<ExerciseGroupItem>(`/exercise-groups/${groupId}/items`, data).then(r => r.data);
export const updateExerciseGroupItem = (groupId: string, itemId: string, data: Record<string, unknown>) => api.put<ExerciseGroupItem>(`/exercise-groups/${groupId}/items/${itemId}`, data).then(r => r.data);
export const removeExerciseGroupItem = (groupId: string, itemId: string) => api.delete(`/exercise-groups/${groupId}/items/${itemId}`).then(r => r.data);

export const toggleFavoriteWorkout = (workoutId: string) => api.post<Workout>(`/workouts/${workoutId}/favorite`).then(r => r.data);
