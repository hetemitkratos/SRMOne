import html2canvas from 'html2canvas';
import { api } from '../api/client.js';

const DAYS = ["Day 1", "Day 2", "Day 3", "Day 4", "Day 5"];
const DAY_LABELS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

// Use precise hex colors to avoid Tailwind JIT missing classes in html2canvas
const SLOT_COLORS = [
  { bg: '#eff6ff', text: '#1e40af' }, // blue
  { bg: '#ecfdf5', text: '#065f46' }, // emerald
  { bg: '#fffbeb', text: '#92400e' }, // amber
  { bg: '#fdf2f8', text: '#9d174d' }, // pink
  { bg: '#eef2ff', text: '#3730a3' }, // indigo
  { bg: '#fef2f2', text: '#991b1b' }, // red
  { bg: '#e0f7f3', text: '#1A1A1A' }, // mint
  { bg: '#e6e6fa', text: '#1A1A1A' }, // lavender
  { bg: '#f5f5dc', text: '#1A1A1A' }  // beige
];

function cleanName(name = "") {
  return String(name)
    .replace(/\(.*?\)/g, "")
    .replace(/^(prof|mrs|ms|mr|dr)\.?\s*/i, "")
    .trim();
}

function getInitials(name = "") {
  const cleaned = cleanName(name);
  if (!cleaned) return "?";
  return cleaned
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

export function generateTimetableImage(timetable, userInfo = {}) {
  return new Promise(async (resolve, reject) => {
    const courses = timetable?.courses || [];
    const advisors = timetable?.advisors || [];
    
    const colorMap = {};
    courses.forEach((c, i) => {
      colorMap[c.courseCode] = SLOT_COLORS[i % SLOT_COLORS.length];
    });

    const daySchedule = {};
    DAYS.forEach(day => daySchedule[day] = []);

    courses.forEach((course) => {
      (course.schedule || []).forEach((s) => {
        if (daySchedule[s.day]) {
          daySchedule[s.day].push({ ...s, course });
        }
      });
    });

    DAYS.forEach(day => {
      daySchedule[day].sort((a, b) => a.hourIndex - b.hourIndex);
    });

    const container = document.createElement('div');
    container.style.position = 'absolute';
    container.style.left = '-9999px';
    container.style.width = '1400px';
    container.style.backgroundColor = '#f8fafc'; // light slate background
    container.style.padding = '40px';
    container.style.fontFamily = 'Arial, Helvetica, sans-serif';
    container.style.boxSizing = 'border-box';
    container.style.lineHeight = '1.5';
    
    let html = `
      <div style="display: flex; flex-direction: column; gap: 32px; background: #ffffff; padding: 40px; border-radius: 32px;">
        
        <!-- Header to match dashboard -->
        <div style="background: #1A1A1A; border-radius: 32px; padding: 40px; display: flex; justify-content: space-between; align-items: center; position: relative; overflow: hidden; min-height: 220px; box-sizing: border-box;">
          <div style="position: absolute; right: 0; top: 0; bottom: 0; width: 350px; opacity: 0.9; mix-blend-mode: screen;">
            <img src="/assets/time-management_4ss6.svg" style="width: 100%; height: 100%; object-fit: contain; object-position: right center;" />
          </div>
          
          <div style="position: relative; z-index: 10; display: flex; gap: 32px; align-items: center;">
            <div style="width: 100px; height: 100px; border-radius: 50%; overflow: hidden; background: #333; border: 4px solid rgba(255,255,255,0.2); flex-shrink: 0;">
              ${userInfo.photoUrl ? `<img src="${userInfo.photoUrl}" style="width: 100%; height: 100%; object-fit: cover;" crossorigin="anonymous" />` : `<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:#333;color:white;font-size:32px;font-weight:bold;">${getInitials(userInfo.name)}</div>`}
            </div>
            <div style="color: white;">
              <h1 style="margin: 0 0 8px 0; font-size: 36px; font-weight: 700; letter-spacing: -0.5px;">${userInfo.name || 'Student Name'}</h1>
              <p style="margin: 0 0 16px 0; font-size: 16px; color: rgba(255,255,255,0.7); font-weight: 500;">${userInfo.email || ''}</p>
              <div style="display: flex; gap: 12px; align-items: center; color: rgba(255,255,255,0.6); font-size: 14px; font-weight: 600;">
                <span>Batch ${timetable?.batch || 'N/A'}</span>
                <span>•</span>
                <span>AY 2024-25</span>
              </div>
            </div>
          </div>
        </div>
    `;

    // Advisors
    if (advisors.length > 0) {
      html += `
        <div style="display: flex; gap: 16px;">
      `;
      advisors.forEach(advisor => {
        const proxied = advisor.photoUrl ? api.facultyPhoto(advisor.photoUrl) : '';
        html += `
          <div style="display: flex; gap: 16px; align-items: center; background: #ffffff; border: 1px solid #f1f5f9; padding: 20px; border-radius: 24px; box-shadow: 0 4px 20px rgba(0,0,0,0.02); flex: 1;">
            <div style="width: 56px; height: 56px; border-radius: 50%; overflow: hidden; background: #e2e8f0; flex-shrink: 0; border: 1px solid rgba(255,255,255,0.7);">
              ${proxied ? `<img src="${proxied}" style="width: 100%; height: 100%; object-fit: cover;" crossorigin="anonymous" />` : `<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:#cbd5e1;color:#1A1A1A;font-size:20px;font-weight:bold;"><span style="line-height: 1; display: block;">${getInitials(advisor.name)}</span></div>`}
            </div>
            <div>
              <p style="margin: 0 0 4px 0; font-size: 10px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px; line-height: 1.2;">${advisor.role || 'Advisor'}</p>
              <p style="margin: 0 0 2px 0; font-size: 15px; font-weight: 700; color: #1A1A1A; line-height: 1.4;">${cleanName(advisor.name)}</p>
              ${advisor.email ? `<p style="margin: 0; font-size: 12px; font-weight: 500; color: #64748b;">${advisor.email}</p>` : ''}
            </div>
          </div>
        `;
      });
      html += `</div>`;
    }

    // Timetable grid
    html += `<div style="display: grid; grid-template-columns: repeat(5, 1fr); gap: 24px;">`;
    
    DAYS.forEach((day, i) => {
      html += `
        <div style="display: flex; flex-direction: column; gap: 16px;">
          <!-- Day Header exactly like UI -->
          <div style="background: white; border-radius: 32px 32px 24px 24px; padding: 20px; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.02); border: 1px solid #f1f5f9;">
            <h3 style="margin: 0 0 4px 0; font-size: 20px; font-weight: 700; color: #1A1A1A;">${DAY_LABELS[i]}</h3>
            <p style="margin: 0; font-size: 10px; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: 1px;">${day}</p>
          </div>
      `;
      
      const classesToday = daySchedule[day];
      if (classesToday.length === 0) {
        html += `
          <div style="background: rgba(255,255,255,0.4); border-radius: 24px; padding: 24px; text-align: center; border: 1px dashed #cbd5e1; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 160px;">
            <img src="/assets/chilling_o2zv.svg" style="width: 70px; height: 70px; opacity: 0.1; margin-bottom: 8px;" />
            <p style="margin: 0; font-size: 14px; font-weight: 700; color: #64748b;">Free Day!</p>
          </div>
        `;
      } else {
        classesToday.forEach(cls => {
          const color = colorMap[cls.course.courseCode] || SLOT_COLORS[0];
          const proxiedFaculty = cls.course.facultyPhotoUrl ? api.facultyPhoto(cls.course.facultyPhotoUrl) : '';
          
          html += `
            <div style="background: ${color.bg}; color: ${color.text}; border: 1px solid rgba(0,0,0,0.05); border-radius: 24px; padding: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);">
              
              <div style="font-size: 10px; font-weight: 700; opacity: 0.7; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 1px; display: flex; align-items: center; gap: 4px;">
                ⏱ ${cls.timing}
              </div>
              
              <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 700; line-height: 1.3;">${cls.course.courseTitle}</p>
              
              <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 16px;">
                <div style="width: 24px; height: 24px; border-radius: 50%; overflow: hidden; background: rgba(0,0,0,0.1); flex-shrink: 0; border: 1px solid rgba(255,255,255,0.7);">
                  ${proxiedFaculty ? `<img src="${proxiedFaculty}" style="width: 100%; height: 100%; object-fit: cover;" crossorigin="anonymous" />` : `<div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:bold;"><span style="line-height: 1; display: block;">${getInitials(cls.course.facultyName)}</span></div>`}
                </div>
                <p style="margin: 0; font-size: 11px; font-weight: 500; opacity: 0.8; max-width: 130px; line-height: 1.5; padding-bottom: 2px;">
                  ${cleanName(cls.course.facultyName)}
                </p>
              </div>
              
              <div style="display: flex; align-items: center; justify-content: space-between; border-top: 1px solid rgba(0,0,0,0.05); padding-top: 12px;">
                <span style="font-size: 10px; font-weight: 800; opacity: 0.7; text-transform: uppercase; letter-spacing: 1px;">
                  ${cls.course.courseCode}
                </span>
                <p style="margin: 0; font-size: 10px; opacity: 0.8; font-weight: 700; display: flex; align-items: center; gap: 4px; line-height: 1;">
                   📍 ${cls.course.roomNo || 'TBA'}
                </p>
              </div>
              
            </div>
          `;
        });
      }
      
      html += `</div>`;
    });
    
    html += `</div>`; // Close grid
    html += `</div>`; // Close main wrapper
    
    container.innerHTML = html;
    document.body.appendChild(container);

    // Wait for all images to load
    const images = Array.from(container.querySelectorAll('img'));
    await Promise.all(images.map(img => {
      if (img.complete) return Promise.resolve();
      return new Promise((resolve) => {
        img.onload = resolve;
        img.onerror = resolve;
      });
    }));
    
    // Wait for fonts to be fully loaded before generating canvas
    if (document.fonts && document.fonts.ready) {
      await document.fonts.ready;
    }

    try {
      const canvas = await html2canvas(container, {
        scale: 2,
        backgroundColor: null,
        logging: false,
        useCORS: true,
        width: 1400,
        height: container.scrollHeight,
        windowWidth: 1400,
        windowHeight: container.scrollHeight
      });
      document.body.removeChild(container);
      
      canvas.toBlob((blob) => {
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `timetable-${new Date().getTime()}.png`;
        link.click();
        URL.revokeObjectURL(url);
        resolve();
      }, 'image/png');
    } catch (error) {
      if (document.body.contains(container)) {
        document.body.removeChild(container);
      }
      reject(error);
    }
  });
}
