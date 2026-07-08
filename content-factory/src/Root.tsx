import React from 'react';
import {
  AbsoluteFill,
  Composition,
  Img,
  staticFile,
  useVideoConfig,
} from 'remotion';
import './styles.css';

type Slide = {
  id: string;
  file: string;
  title: string;
  rotate: number;
  x: number;
  y: number;
  scale: number;
  secondary?: string;
  tertiary?: string;
};

const slides: Slide[] = [
  {
    id: 'overview-metrics',
    file: 'demo_dashboard.png',
    title: 'Cải thiện bằng dữ liệu',
    rotate: -7,
    x: 118,
    y: 292,
    scale: 1.02,
    secondary: 'demo_stats.png',
  },
  {
    id: 'chatbot',
    file: 'demo_chatbot.png',
    title: 'Huấn luyện viên AI\ncủa riêng bạn',
    rotate: 6,
    x: 122,
    y: 298,
    scale: 1.03,
  },
  {
    id: 'personalized-training',
    file: 'demo_training_schedule.png',
    title: 'Giáo án tập luyện\ncá nhân hóa',
    rotate: -4,
    x: 120,
    y: 290,
    scale: 1.03,
    secondary: 'demo_training_schedule_ai_create.png',
  },
  {
    id: 'smart-nutrition',
    file: 'demo_nutrition_logging.png',
    title: 'Nhật ký dinh dưỡng\nthông minh',
    rotate: 4,
    x: 120,
    y: 250,
    scale: 0.84,
    secondary: 'demo_food_recognition.png',
    tertiary: 'demo_food_recommendation.png',
  },
];

const slideById = Object.fromEntries(slides.map((slide) => [slide.id, slide]));

export const getSlides = () => slides;

type PhoneProps = {
  file: string;
  rotate: number;
  x: number;
  y: number;
  scale: number;
  ghost?: boolean;
};

const Phone = ({file, rotate, x, y, scale, ghost = false}: PhoneProps) => {
  return (
    <div
      className={`phone ${ghost ? 'phoneGhost' : ''}`}
      style={{
        left: x,
        top: y,
        transform: `rotate(${rotate}deg) scale(${scale})`,
      }}
    >
      <div className="phoneBezel">
        <div className="statusBar">
          <span>10:19</span>
          <div className="statusIcons">
            <span className="signal" />
            <span className="wifi" />
            <span className="battery" />
          </div>
        </div>
        <div className="speaker" />
        <div className="screenFrame">
          <Img
            className="screen"
            src={staticFile(`screenshots/${file}`)}
            alt=""
          />
        </div>
      </div>
    </div>
  );
};

const RunnyMarketing = ({slideId = 'overview-metrics'}: {slideId?: string}) => {
  const slide = slideById[slideId] ?? slides[0];
  const {width, height} = useVideoConfig();

  return (
    <AbsoluteFill className="stage">
      <Img
        className="runnerBackground"
        src={staticFile('runnner_background.jpg')}
        alt=""
      />
      <div className="backgroundScrim" />
      <div className="grain" />
      <div className="brand">RUNNY AI</div>
      <div className="copy">
        <h1>{slide.title}</h1>
      </div>
      {slide.secondary ? (
        slide.tertiary ? (
          <>
            <Phone
              file={slide.secondary}
              rotate={slide.rotate - 15}
              x={-110}
              y={height * 0.3}
              scale={0.6}
              ghost
            />
            <Phone
              file={slide.tertiary}
              rotate={slide.rotate + 11}
              x={414}
              y={height * 0.31}
              scale={0.6}
              ghost
            />
          </>
        ) : (
          <Phone
            file={slide.secondary}
            rotate={slide.rotate - 12}
            x={-104}
            y={height * 0.39}
            scale={0.77}
            ghost
          />
        )
      ) : null}
      <Phone
        file={slide.file}
        rotate={slide.rotate}
        x={slide.x}
        y={slide.y}
        scale={slide.scale}
      />
      <div className="bottomGlow" style={{width}} />
    </AbsoluteFill>
  );
};

export const Root = () => {
  return (
    <Composition
      id="RunnyMarketing"
      component={RunnyMarketing}
      durationInFrames={1}
      fps={30}
      width={720}
      height={1200}
      defaultProps={{slideId: 'overview-metrics'}}
    />
  );
};
